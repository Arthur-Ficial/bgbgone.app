import Foundation

/// Bounded-concurrency executor over `BgBgOneRunning`. Pure logic — does not own
/// `[ImageFile]` state; `AppViewModel` does. Callers pass in `(id, args)` pairs
/// and receive lifecycle callbacks.
///
/// `maxConcurrent` defaults to a CPU-derived cap; the `--debug` Tweaks panel can
/// override it for an interactive throughput knob.
struct QueueRunner: Sendable {
    let runner: any BgBgOneRunning
    let maxConcurrent: Int

    /// One unit of work — pre-validated argv plus the `ImageFile.id` so the caller
    /// can map results back into its `[ImageFile]` array.
    struct WorkItem: Sendable, Hashable {
        let id: UUID
        let arguments: [String]
    }

    init(runner: any BgBgOneRunning, maxConcurrent: Int? = nil) {
        self.runner = runner
        self.maxConcurrent = maxConcurrent ?? Self.defaultMaxConcurrent()
    }

    /// Default = min(4, active CPUs ÷ 2). bgbgone is CPU-heavy under the hood and
    /// running too many in parallel stalls all of them.
    static func defaultMaxConcurrent() -> Int {
        min(4, max(1, ProcessInfo.processInfo.activeProcessorCount / 2))
    }

    /// Process every item, never exceeding `maxConcurrent` in-flight at any moment.
    /// `onStart` fires when an item moves from queued → processing; `onResult` fires
    /// when it terminates (success or failure). Both run on the caller's actor.
    ///
    /// One bad item never stops the others — errors are surfaced via `onResult`.
    func process(
        _ items: [WorkItem],
        onStart: @Sendable @escaping (UUID) async -> Void,
        onResult: @Sendable @escaping (UUID, Result<RunResult, Error>) async -> Void
    ) async {
        await withTaskGroup(of: Void.self) { group in
            var inFlight = 0
            var iter = items.makeIterator()
            let runner = self.runner

            while inFlight < maxConcurrent, let item = iter.next() {
                inFlight += 1
                group.addTask {
                    await onStart(item.id)
                    let result: Result<RunResult, Error>
                    do {
                        result = .success(try await runner.run(arguments: item.arguments))
                    } catch {
                        result = .failure(error)
                    }
                    await onResult(item.id, result)
                }
            }

            for await _ in group {
                if let item = iter.next() {
                    group.addTask {
                        await onStart(item.id)
                        let result: Result<RunResult, Error>
                        do {
                            result = .success(try await runner.run(arguments: item.arguments))
                        } catch {
                            result = .failure(error)
                        }
                        await onResult(item.id, result)
                    }
                }
            }
        }
    }
}
