import Foundation
import Observation
import os

/// Top-level UI state owner. Views observe `files`, `batches`, `selectedId`, `config`,
/// `dropPhase`, `bootState`. Views never own state — they emit intents back to this
/// type. Pure I/O happens in injected Services (`BgBgOneRunning`, `FolderScanning`,
/// `ImageMetaReading`).
@MainActor
@Observable
final class AppViewModel {
    /// Whether we've located the bgbgone binary. Drives `MissingBinaryView`.
    enum BootState: Equatable {
        case starting
        case ready(binary: URL)
        case missingBinary(searched: [String])
    }

    private(set) var bootState: BootState = .starting

    var files: [ImageFile] = []
    var batches: [Batch] = []
    var selectedId: ImageFile.ID?
    var config: Config = Config(outDirectory: Config.defaultOutDirectory)

    let dropMachine: DropMachine

    /// `nil` when the binary couldn't be located. The UI shows `MissingBinaryView` and
    /// disables actions in that case; `processAll()` early-returns. We do not ship a
    /// stub runner — a stub is the "fake fallback" the no-fake-UI charter forbids.
    private let runner: (any BgBgOneRunning)?
    private let scanner: any FolderScanning
    private let metaReader: any ImageMetaReading
    private let logger = Logger(subsystem: BuildInfo.osLogSubsystem, category: "app")

    // MARK: - init

    /// Production initialiser — discovers the binary via `BinaryLocator`. Views call
    /// this with no arguments.
    convenience init() {
        let locator = BinaryLocator()
        let bootState: BootState
        let runner: (any BgBgOneRunning)?
        do {
            let binary = try locator.locate()
            bootState = .ready(binary: binary)
            runner = BgBgOneRunner(binary: binary)
        } catch BinaryLocator.LocatorError.notFound(let searched) {
            bootState = .missingBinary(searched: searched)
            runner = nil
        } catch {
            bootState = .missingBinary(searched: ["unknown: \(error)"])
            runner = nil
        }
        self.init(
            runner: runner,
            scanner: FolderScanner(),
            metaReader: ImageMetaReader(),
            bootState: bootState
        )
    }

    /// Test-friendly initialiser. Tests pass mocks for all three services so the
    /// integration test runs without spawning anything or touching disk.
    init(
        runner: (any BgBgOneRunning)?,
        scanner: any FolderScanning,
        metaReader: any ImageMetaReading,
        bootState: BootState
    ) {
        self.runner = runner
        self.scanner = scanner
        self.metaReader = metaReader
        self.bootState = bootState
        self.dropMachine = DropMachine()
    }

    // MARK: - Drag / drop

    func handleDragEnter(hint: DragHint) { dropMachine.handleDragEnter(hint: hint) }
    func handleDragLeave() { dropMachine.handleDragLeave() }
    func dismissSummary() { dropMachine.dismissSummary() }

    /// Called when the user drops folders / files on the window.
    ///
    /// Folders are scanned recursively (one `Batch` per folder); loose images go into
    /// no batch. Each new `ImageFile` starts in `.raw` state.
    func handleDrop(urls: [URL]) async {
        // Classify the drop so we can name the ingest progress card.
        let folderURLs = urls.filter { Self.isDirectory($0) }
        let looseImageURLs = urls.filter { !Self.isDirectory($0) && Self.isImage($0) }
        let folderName = folderURLs.first?.lastPathComponent ?? "dropped"
        dropMachine.handleDrop(folderName: folderName)

        var addedImages: [ImageFile] = []

        // 1. Loose images first — no batch, just appear in the queue.
        for url in looseImageURLs {
            let file = makeImageFile(at: url, batchId: nil, relativePath: "")
            addedImages.append(file)
            dropMachine.applyScanEvent(.foundImage(url: url, relativePath: url.lastPathComponent))
            dropMachine.applyScanEvent(.scanned(url: url, isImage: true))
        }

        // 2. Folders, one batch per folder.
        var totalScanned = 0
        var totalSkipped = 0
        for folder in folderURLs {
            let batch = Batch(name: folder.lastPathComponent, addedAt: .now)
            batches.append(batch)
            for await event in scanner.scan(folder) {
                switch event {
                case .foundImage(let url, let relativePath):
                    let file = makeImageFile(at: url, batchId: batch.id, relativePath: relativePath)
                    addedImages.append(file)
                    if let idx = batches.firstIndex(where: { $0.id == batch.id }) {
                        batches[idx].imageCount += 1
                    }
                    dropMachine.applyScanEvent(event)
                case .scanned:
                    totalScanned += 1
                    dropMachine.applyScanEvent(event)
                case .skipped:
                    totalSkipped += 1
                    if let idx = batches.firstIndex(where: { $0.id == batch.id }) {
                        batches[idx].skippedCount += 1
                    }
                    dropMachine.applyScanEvent(event)
                case .completed(_, let scannedCount, let skippedCount):
                    totalScanned += scannedCount
                    totalSkipped += skippedCount
                    // Don't forward .completed to the drop machine yet — wait until ALL
                    // folders are done so the summary fires once.
                    break
                }
            }
        }

        files.append(contentsOf: addedImages)
        if selectedId == nil, let first = addedImages.first { selectedId = first.id }

        dropMachine.applyScanEvent(.completed(
            images: addedImages.map(\.url),
            scannedCount: totalScanned + looseImageURLs.count,
            skippedCount: totalSkipped
        ))
    }

    /// Build an `ImageFile`, reading dims/bytes synchronously. Sync is fine here —
    /// `ImageMetaReader` doesn't decode pixels and runs in well under a millisecond.
    private func makeImageFile(at url: URL, batchId: Batch.ID?, relativePath: String) -> ImageFile {
        var file = ImageFile(url: url, batchId: batchId, relativePath: relativePath)
        if let meta = try? metaReader.read(url) {
            file.width = meta.width
            file.height = meta.height
            file.bytes = meta.bytes
        }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let modified = attrs[.modificationDate] as? Date {
            file.modifiedAt = modified
        }
        return file
    }

    // MARK: - Queue

    /// Number of files in the queue that still need work.
    var pendingCount: Int {
        files.lazy.filter { f in
            switch f.state {
            case .raw, .error, .queued, .processing: true
            case .done: false
            }
        }.count
    }

    /// "Remove background from N" → enqueue every `.raw` / `.error` file.
    ///
    /// No-op when the binary is missing: the UI shows `MissingBinaryView` and disables
    /// the toolbar action, so this is the explicit assertion of that invariant rather
    /// than a fallback.
    func processAll() async {
        guard let runner else { return }

        for idx in files.indices where files[idx].state.isRequeueable {
            files[idx].state = .queued
        }
        let workItems: [QueueRunner.WorkItem] = files.compactMap { file in
            guard file.state == .queued else { return nil }
            let output = BgBgOneCommand.resolveOutputURL(
                for: file.url,
                in: config.outDirectory,
                pattern: config.namePattern,
                format: config.format
            )
            let cmd = BgBgOneCommand(
                input: file.url,
                output: output,
                background: config.background,
                format: config.format
            )
            guard let args = try? cmd.arguments() else { return nil }
            return QueueRunner.WorkItem(id: file.id, arguments: args)
        }

        let queue = QueueRunner(runner: runner)
        await queue.process(
            workItems,
            onStart: { [weak self] id in
                Task { @MainActor in self?.markProcessing(id: id) }
            },
            onResult: { [weak self] id, result in
                Task { @MainActor in self?.markFinished(id: id, result: result) }
            }
        )
    }

    private func markProcessing(id: UUID) {
        guard let idx = files.firstIndex(where: { $0.id == id }) else { return }
        files[idx].state = .processing
    }

    private func markFinished(id: UUID, result: Result<RunResult, Error>) {
        guard let idx = files.firstIndex(where: { $0.id == id }) else { return }
        switch result {
        case .success(let outcome):
            files[idx].state = .done(milliseconds: outcome.durationMillis)
        case .failure(let err):
            files[idx].state = .error(message: "\(err)")
            logger.error("file \(id.uuidString, privacy: .public) failed: \(String(describing: err), privacy: .public)")
        }
    }

    // MARK: - Helpers

    private static func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    private static func isImage(_ url: URL) -> Bool {
        FolderScanner.imageExtensions.contains(url.pathExtension.lowercased())
    }
}

