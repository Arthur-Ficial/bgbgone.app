// bgbgone — refined: quieter, more whitespace, fewer affordances.

const { useState, useEffect, useMemo, useRef } = React;

/* ============== Helpers ============== */
function bytesToHuman(n) {
  if (n >= 1_000_000) return (n/1_000_000).toFixed(1) + " MB";
  if (n >= 1_000) return (n/1_000).toFixed(0) + " KB";
  return n + " B";
}
function megapixels(w, h) { return ((w*h)/1_000_000).toFixed(1) + " MP"; }
function namePreview(file, pattern, format) {
  const base = file.name.replace(/\.[^.]+$/, "");
  return pattern
    .replace(/\{name\}/g, base)
    .replace(/\{base\}/g, base)
    .replace(/\{ext\}/g, format)
    .replace(/\{n:?(\d*)\}/g, (_, p) => "1".padStart(parseInt(p)||1, "0"));
}

/* ============== Icons ============== */
const Icon = ({ name, size = 14 }) => {
  const sw = 1.5, st = "currentColor";
  switch (name) {
    case "folder": return <svg width={size} height={size} viewBox="0 0 16 16" fill="none"><path d="M2 5a1 1 0 0 1 1-1h3l1.5 1.5H13a1 1 0 0 1 1 1V12a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V5Z" stroke={st} strokeWidth={sw} strokeLinejoin="round"/></svg>;
    case "plus":   return <svg width={size} height={size} viewBox="0 0 16 16" fill="none"><path d="M8 4v8M4 8h8" stroke={st} strokeWidth={sw} strokeLinecap="round"/></svg>;
    case "drop":   return <svg width={size} height={size} viewBox="0 0 48 48" fill="none">
      <rect x="6" y="10" width="36" height="28" rx="3" stroke={st} strokeWidth="1.4" strokeDasharray="4 3"/>
      <path d="M24 16v12M19 23l5 5 5-5" stroke={st} strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>;
    case "arrow-right": return <svg width={size} height={size} viewBox="0 0 16 16" fill="none"><path d="M3 8h10M9 4l4 4-4 4" stroke={st} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"/></svg>;
    default: return null;
  }
};

/* ============== Placeholder image ============== */
function Subject({ kind, palette }) {
  const [p1, p2, p3] = palette;
  switch (kind) {
    case "portrait":
    case "portrait-painting":
      return <g>
        <ellipse cx="50" cy="68" rx="22" ry="32" fill={p2}/>
        <circle cx="50" cy="32" r="13" fill={p1}/>
      </g>;
    case "group":
      return <g>
        <rect x="14" y="48" width="22" height="34" rx="11" fill={p1}/><circle cx="25" cy="40" r="9" fill={p1}/>
        <rect x="38" y="42" width="24" height="40" rx="12" fill={p2}/><circle cx="50" cy="32" r="11" fill={p2}/>
        <rect x="64" y="48" width="22" height="34" rx="11" fill={p3||p1}/><circle cx="75" cy="40" r="9" fill={p3||p1}/>
      </g>;
    case "product-shoe":
      return <g>
        <ellipse cx="50" cy="62" rx="34" ry="11" fill={p1}/>
        <rect x="22" y="50" width="55" height="14" rx="7" fill={p1}/>
        <ellipse cx="32" cy="52" rx="14" ry="9" fill={p2}/>
        <rect x="42" y="44" width="22" height="10" rx="3" fill={p2}/>
      </g>;
    case "product-mug":
      return <g>
        <rect x="32" y="34" width="30" height="36" rx="3" fill={p1}/>
        <circle cx="68" cy="52" r="9" fill="none" stroke={p1} strokeWidth="4"/>
      </g>;
    case "product-tomato":
      return <g>
        <circle cx="50" cy="56" r="22" fill={p1}/>
        <ellipse cx="50" cy="36" rx="9" ry="4" fill={p2}/>
      </g>;
    case "product-typewriter":
      return <g>
        <rect x="22" y="42" width="56" height="22" rx="3" fill={p1}/>
        <rect x="30" y="34" width="40" height="10" rx="2" fill={p2}/>
      </g>;
    case "product-rover":
      return <g>
        <rect x="24" y="44" width="52" height="22" rx="3" fill={p1}/>
        <rect x="32" y="32" width="22" height="14" fill={p2}/>
        <circle cx="34" cy="70" r="6" fill={p2}/><circle cx="66" cy="70" r="6" fill={p2}/>
      </g>;
    case "product-lemons":
      return <g>
        <ellipse cx="38" cy="56" rx="18" ry="14" fill={p1}/>
        <ellipse cx="62" cy="58" rx="20" ry="15" fill={p1}/>
        <ellipse cx="50" cy="46" rx="16" ry="12" fill={p1}/>
      </g>;
    case "product-bag":
      return <g>
        <rect x="28" y="38" width="44" height="38" rx="4" fill={p1}/>
        <path d="M 36 38 Q 36 22 50 22 Q 64 22 64 38" stroke={p1} strokeWidth="4" fill="none"/>
      </g>;
    case "product-bonsai":
      return <g>
        <ellipse cx="50" cy="36" rx="26" ry="14" fill={p1}/>
        <rect x="46" y="44" width="8" height="22" fill={p2}/>
        <rect x="32" y="64" width="36" height="10" rx="2" fill={p2}/>
      </g>;
    case "product-machine":
      return <g>
        <rect x="30" y="30" width="40" height="42" rx="4" fill={p1}/>
        <rect x="38" y="48" width="24" height="18" fill={p2}/>
      </g>;
    case "product-guitar":
      return <g>
        <ellipse cx="62" cy="58" rx="18" ry="22" fill={p1}/>
        <rect x="20" y="50" width="42" height="6" fill={p2}/>
      </g>;
    default: return <circle cx="50" cy="55" r="22" fill={p1}/>;
  }
}

function Thumb({ file, mode = "raw", composite, className }) {
  const id = `chk-${file.id}-${mode}`;
  let bgFill;
  if (mode === "raw") {
    bgFill = <foreignObject x="0" y="0" width="100" height="100"><div style={{ width: "100%", height: "100%", background: file.bg }}/></foreignObject>;
  } else if (mode === "cutout") {
    bgFill = <>
      <defs><pattern id={id} width="10" height="10" patternUnits="userSpaceOnUse">
        <rect width="5" height="5" fill="#ffffff"/><rect x="5" width="5" height="5" fill="#e3e3e3"/>
        <rect y="5" width="5" height="5" fill="#e3e3e3"/><rect x="5" y="5" width="5" height="5" fill="#ffffff"/>
      </pattern></defs>
      <rect width="100" height="100" fill={`url(#${id})`}/>
    </>;
  } else {
    bgFill = <foreignObject x="0" y="0" width="100" height="100"><div style={{ width: "100%", height: "100%", background: composite || "#fff" }}/></foreignObject>;
  }
  return (
    <svg viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice" className={className}>
      {bgFill}
      <Subject kind={file.kind} palette={file.palette}/>
    </svg>
  );
}

/* ============== Drop overlays ============== */

// What the cursor is carrying. Drives the veil copy.
function dragLabel(hint) {
  if (!hint) return { primary: "Drop to add", sub: "" };
  const { folderCount, imageCount, otherCount, folderName } = hint;

  if (folderCount === 1 && imageCount === 0 && otherCount === 0) {
    return {
      primary: <>Add folder <em className="hint-em">{folderName}</em></>,
      sub: "We'll scan it for images, including sub-folders.",
    };
  }
  if (folderCount > 1) {
    return {
      primary: <>Add <b>{folderCount}</b> folders</>,
      sub: "We'll scan each one for images, recursively.",
    };
  }
  if (folderCount === 1 && imageCount > 0) {
    return {
      primary: <>Add folder <em className="hint-em">{folderName}</em> + <b>{imageCount}</b> {imageCount === 1 ? "image" : "images"}</>,
      sub: otherCount > 0 ? `${otherCount} non-image ${otherCount === 1 ? "file" : "files"} will be skipped.` : "",
    };
  }
  if (imageCount > 1) {
    return {
      primary: <>Add <b>{imageCount}</b> images</>,
      sub: otherCount > 0 ? `${otherCount} non-image ${otherCount === 1 ? "file" : "files"} will be skipped.` : "",
    };
  }
  if (imageCount === 1) {
    return { primary: <>Add <b>1</b> image</>, sub: "" };
  }
  if (otherCount > 0) {
    return {
      primary: <>Nothing to add</>,
      sub: `${otherCount} ${otherCount === 1 ? "file is" : "files are"} not images — drop PNG · JPG · HEIC · TIFF · AVIF.`,
      blocked: true,
    };
  }
  return { primary: "Drop to add", sub: "" };
}

function DropVeil({ hint }) {
  const { primary, sub, blocked } = dragLabel(hint);
  return (
    <div className={`drop-veil ${blocked ? "blocked" : ""}`}>
      <div className="drop-veil-card">
        <div className="drop-veil-glyph">
          {blocked ? (
            <svg width="44" height="44" viewBox="0 0 44 44" fill="none">
              <circle cx="22" cy="22" r="17" stroke="currentColor" strokeWidth="1.6"/>
              <path d="M11 11l22 22" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round"/>
            </svg>
          ) : hint?.folderCount > 0 ? (
            <svg width="48" height="44" viewBox="0 0 48 44" fill="none">
              <path d="M3 10a2 2 0 0 1 2-2h11l4 4h21a2 2 0 0 1 2 2v22a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V10Z" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round" fill="none"/>
              <path d="M14 22h20M14 28h13" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" opacity="0.55"/>
            </svg>
          ) : (
            <svg width="44" height="44" viewBox="0 0 44 44" fill="none">
              <rect x="6" y="8" width="32" height="28" rx="3" stroke="currentColor" strokeWidth="1.6" strokeDasharray="3 3"/>
              <path d="M22 14v12M16 21l6 6 6-6" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          )}
        </div>
        <div className="drop-veil-primary">{primary}</div>
        {sub && <div className="drop-veil-sub">{sub}</div>}
      </div>
    </div>
  );
}

/* ============== Ingestion overlay ============== */

function IngestOverlay({ state }) {
  // state: { folderName, scanned, found, paths: ["folder/sub/foo.jpg", ...] }
  const pct = Math.min(100, Math.round((state.scanned / Math.max(state.scanned + 6, 32)) * 100));
  return (
    <div className="ingest-overlay">
      <div className="ingest-card">
        <div className="ingest-row">
          <div className="ingest-folder-icon">
            <Icon name="folder" size={18}/>
          </div>
          <div className="ingest-text">
            <div className="ingest-title">Scanning <em>{state.folderName}</em></div>
            <div className="ingest-sub mono">
              <b>{state.found}</b> images found
              <span className="sep">·</span>
              <b>{state.scanned}</b> items checked
            </div>
          </div>
        </div>
        <div className="ingest-track"><div className="ingest-fill" style={{ width: pct + "%" }}/></div>
        <div className="ingest-tail mono">
          {state.paths.map((p, i) => (
            <div key={i} className="ingest-tail-row" style={{ opacity: 1 - i * 0.18 }}>
              <span className="ingest-tail-icon">+</span>
              <span className="ingest-tail-path">{p}</span>
            </div>
          ))}
        </div>
        <button className="ingest-cancel">Cancel scan</button>
      </div>
    </div>
  );
}

/* ============== Drop summary banner ============== */

function DropSummary({ summary, onDismiss, onShowSkipped }) {
  if (!summary) return null;
  return (
    <div className="drop-summary">
      <span className="ds-dot"/>
      <span className="ds-main">
        Added <b>{summary.added}</b> {summary.added === 1 ? "image" : "images"}
        {summary.folderName && <> from <em>{summary.folderName}</em></>}
      </span>
      {(summary.skipped > 0 || summary.duped > 0) && (
        <span className="ds-aux">
          {summary.skipped > 0 && (
            <>
              <span className="ds-sep">·</span>
              <button className="ds-link" onClick={onShowSkipped}>
                {summary.skipped} skipped
              </button>
            </>
          )}
          {summary.duped > 0 && (
            <>
              <span className="ds-sep">·</span>
              <span className="ds-mute">{summary.duped} already in queue</span>
            </>
          )}
        </span>
      )}
      <button className="ds-close" onClick={onDismiss} aria-label="Dismiss">×</button>
    </div>
  );
}

/* ============== Title bar ============== */
function TitleBar({ pending, onProcessAll, onAdd }) {
  return (
    <div className="titlebar">
      <div className="tl-dots"><span className="tl r"/><span className="tl y"/><span className="tl g"/></div>
      <div className="tb-brand">bgbgone</div>
      <div className="tb-actions">
        <button className="btn" onClick={onAdd}>Add files…</button>
        <button className="btn primary" disabled={pending === 0} onClick={onProcessAll}>
          {pending > 0 ? <>Remove background from <b>{pending}</b></> : "All done"}
        </button>
      </div>
    </div>
  );
}

/* ============== Dual view ============== */
function DualView({ file, bgKind, bgColor, onPickFiles, onPickFolder, isEmpty }) {
  if (!file) {
    return (
      <div className="dual">
        <div className="dual-pane dual-pane-empty" style={{ gridColumn: "1 / -1" }}>
          <div className="dual-empty">
            <div className="dual-empty-icon">
              <svg width="68" height="56" viewBox="0 0 68 56" fill="none">
                <path d="M4 14a3 3 0 0 1 3-3h14l5 5h35a3 3 0 0 1 3 3v30a3 3 0 0 1-3 3H7a3 3 0 0 1-3-3V14Z" stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round" fill="none"/>
                <path d="M34 24v14M28 32l6 6 6-6" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </div>
            <div className="dual-empty-title">
              {isEmpty ? "Drop a folder or images to begin." : "Select an image to preview."}
            </div>
            <div className="dual-empty-sub">PNG · JPG · HEIC · TIFF · AVIF · sub-folders OK</div>
            {isEmpty && (
              <div className="dual-empty-ctas">
                <button className="btn primary" onClick={onPickFolder}>Choose folder…</button>
                <button className="btn" onClick={onPickFiles}>Choose files…</button>
              </div>
            )}
          </div>
        </div>
      </div>
    );
  }
  const afterMode = bgKind === "color" ? "composite" : "cutout";
  return (
    <div className="dual">
      <div className="dual-pane">
        <span className="dual-tag">Original</span>
        <Thumb file={file} mode="raw" className="dual-img"/>
      </div>
      <div className="dual-pane">
        <span className="dual-tag">Removed</span>
        <Thumb file={file} mode={afterMode} composite={bgColor} className="dual-img"/>
      </div>
    </div>
  );
}

/* ============== Selected meta ============== */
function SelectedMeta({ file }) {
  if (!file) return null;
  return (
    <div className="sel-meta">
      <span className="sel-name">{file.name}</span>
      <span className="sel-info mono">
        {file.w} × {file.h}
        <span className="sep">·</span>
        {bytesToHuman(file.bytes)}
        {file.ms && <><span className="sep">·</span>removed in {file.ms} ms</>}
      </span>
      <span className={`sel-status ${file.state}`}>
        {file.state === "done" ? "Done" :
         file.state === "raw" ? "Not removed" :
         file.state === "queued" ? "Queued" :
         file.state === "processing" ? "Removing…" :
         file.state === "error" ? "Failed" : file.state}
      </span>
    </div>
  );
}

/* ============== Config ============== */
const COLOR_PRESETS = ["#ffffff", "#000000", "#0066cc", "#f06a3a", "#2da94f"];
const FORMAT_LABELS = { png: "PNG", jpg: "JPEG", heic: "HEIC", tiff: "TIFF" };

function Config({ cfg, setCfg }) {
  return (
    <div className="config">
      <span className="cfg-label">Save to</span>
      <div className="cfg-control">
        <button className="path-display" title="Choose folder">
          <span className="folder-icon"><Icon name="folder"/></span>
          <span className="path-text">{cfg.outDir}</span>
        </button>
      </div>

      <span className="cfg-label">Name as</span>
      <div className="cfg-control">
        <input
          className="text-input"
          value={cfg.namePattern}
          onChange={(e) => setCfg(c => ({ ...c, namePattern: e.target.value }))}
        />
        <div className="tokens">
          {["{name}", "{ext}", "{n:02}"].map(t => (
            <button key={t} className="token" onClick={() => setCfg(c => ({ ...c, namePattern: c.namePattern + t }))}>{t}</button>
          ))}
        </div>
      </div>

      <span className="cfg-label">Background</span>
      <div className="cfg-control">
        <div className="radios">
          <button className={`radio ${cfg.bgKind === "none" ? "active" : ""}`} onClick={() => setCfg(c => ({ ...c, bgKind: "none" }))}>
            <span className="radio-sw checker"/> Transparent
          </button>
          <button className={`radio ${cfg.bgKind === "color" ? "active" : ""}`} onClick={() => setCfg(c => ({ ...c, bgKind: "color" }))}>
            <span className="radio-sw" style={{ background: cfg.bgColor }}/> Color
          </button>
          <button className={`radio ${cfg.bgKind === "image" ? "active" : ""}`} onClick={() => setCfg(c => ({ ...c, bgKind: "image" }))}>
            Image…
          </button>
        </div>
        {cfg.bgKind === "color" && (
          <div style={{ display: "flex", gap: 6, marginLeft: 12, alignItems: "center" }}>
            {COLOR_PRESETS.map(c => (
              <button key={c} className={`color-sw ${cfg.bgColor === c ? "active" : ""}`} style={{ background: c }} onClick={() => setCfg(s => ({ ...s, bgColor: c }))}/>
            ))}
            <input className="color-hex" value={cfg.bgColor} onChange={(e) => setCfg(s => ({ ...s, bgColor: e.target.value }))}/>
          </div>
        )}
      </div>

      <span className="cfg-label">Format</span>
      <div className="cfg-control">
        <div className="radios">
          {Object.entries(FORMAT_LABELS).map(([k, v]) => (
            <button key={k} className={`radio ${cfg.format === k ? "active" : ""}`} onClick={() => setCfg(c => ({ ...c, format: k }))}>
              {v}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

/* ============== File list ============== */
function FileList({ files, batches, selectedId, setSelectedId, onCollapseBatch, dragover, setDragover, onDrop, summary, onDismissSummary, onShowSkipped }) {
  // Build a render order: when a file is the first in a batch, prepend a batch header.
  const firstSeen = new Map();
  files.forEach(f => {
    if (f.batchId && !firstSeen.has(f.batchId)) firstSeen.set(f.batchId, f.id);
  });

  return (
    <div
      className="files"
      onDragOver={(e) => { e.preventDefault(); setDragover(true); }}
      onDragLeave={(e) => { if (e.currentTarget === e.target) setDragover(false); }}
      onDrop={(e) => { e.preventDefault(); setDragover(false); onDrop?.(e); }}
    >
      <div className="files-head">
        <span className="files-head-title">
          <b>{files.length}</b> {files.length === 1 ? "image" : "images"}
          {batches.length > 0 && <> · <b>{batches.length}</b> {batches.length === 1 ? "folder" : "folders"}</>}
        </span>
        <span className="files-head-spacer"/>
        <DropSummary summary={summary} onDismiss={onDismissSummary} onShowSkipped={onShowSkipped}/>
      </div>
      <div className="files-scroll">
        {files.length === 0 ? (
          <div className="files-empty">
            <Icon name="drop" size={48}/>
            <div style={{ font: "500 14px/1 var(--font-display)", color: "var(--fg)" }}>Drop a folder or images here</div>
            <div style={{ font: "11.5px var(--font-mono)", color: "var(--fg-faint)" }}>or use Add files…</div>
          </div>
        ) : files.map(f => {
          const isBatchStart = f.batchId && firstSeen.get(f.batchId) === f.id;
          const batch = isBatchStart ? batches.find(b => b.id === f.batchId) : null;
          return (
            <React.Fragment key={f.id}>
              {batch && (
                <div className="batch-row">
                  <button
                    className="batch-toggle"
                    onClick={() => onCollapseBatch(batch.id)}
                    aria-expanded={!batch.collapsed}
                  >
                    <svg width="10" height="10" viewBox="0 0 10 10" style={{ transform: batch.collapsed ? "rotate(-90deg)" : "none", transition: "transform .12s" }}>
                      <path d="M2 4l3 3 3-3" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" fill="none"/>
                    </svg>
                    <span className="batch-folder-icon"><Icon name="folder" size={13}/></span>
                    <span className="batch-name">{batch.name}</span>
                  </button>
                  <span className="batch-meta mono">
                    {batch.imageCount} {batch.imageCount === 1 ? "image" : "images"}
                    {batch.skipped > 0 && <> · <span className="batch-skip">{batch.skipped} skipped</span></>}
                  </span>
                  <span className="batch-added mono">added {batch.addedAt}</span>
                </div>
              )}
              {!(f.batchId && batches.find(b => b.id === f.batchId)?.collapsed) && (
                <div
                  className={`file-row ${selectedId === f.id ? "selected" : ""} ${f.batchId ? "in-batch" : ""}`}
                  onClick={() => setSelectedId(f.id)}
                >
                  <div className="fr-thumb"><Thumb file={f} mode={f.state === "done" ? "cutout" : "raw"}/></div>
                  <span className="fr-name">{f.batchId && <span className="fr-relpath mono">{f.relPath}</span>}{f.name}</span>
                  <span className="fr-dims">{f.w} × {f.h}</span>
                  <span className={`fr-state ${f.state}`}>
                    {f.state === "done" ? `Done · ${f.ms} ms` :
                    f.state === "raw" ? "Not removed" :
                    f.state === "queued" ? "Queued" :
                    f.state === "processing" ? "Removing…" :
                    f.state === "error" ? "Failed" : f.state}
                  </span>
                  <span className="fr-added">{f.modified}</span>
                </div>
              )}
            </React.Fragment>
          );
        })}
      </div>
    </div>
  );
}

/* ============== Status bar ============== */
function StatusBar({ files, cfg }) {
  const total = files.length;
  const done = files.filter(f => f.state === "done").length;
  const errors = files.filter(f => f.state === "error").length;
  const sample = files[0];
  const samplePreview = sample ? namePreview(sample, cfg.namePattern, cfg.format) : "{name}";
  return (
    <div className="statusbar">
      <span className="status-grp">on-device · Vision</span>
      {total > 0 && <><span className="status-arrow">·</span><span className="status-grp"><b>{done}</b> of {total} done{errors > 0 && <>, <b style={{ color: "var(--red)" }}>{errors}</b> failed</>}</span></>}
      <span className="right">
        <span className="mono">→ {cfg.outDir}/{samplePreview}.{cfg.format}</span>
      </span>
    </div>
  );
}

/* ============== App ============== */
const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "accent": "#007aff",
  "dropDemo": "idle"
}/*EDITMODE-END*/;

// Sample batches that came from folder drops earlier.
const SAMPLE_BATCHES = [
  { id: "b1", name: "summer-shoot", imageCount: 6, skipped: 2, addedAt: "09:14", collapsed: false },
  { id: "b2", name: "product-archive/2025-q2", imageCount: 5, skipped: 0, addedAt: "Yesterday", collapsed: false },
];

// Map the existing sample files into the two batches so grouping is visible by default.
function enrichFiles(files) {
  return files.map((f, i) => {
    if (i < 6) return { ...f, batchId: "b1", relPath: "summer-shoot/" };
    if (i < 11) return { ...f, batchId: "b2", relPath: "product-archive/2025-q2/" };
    return f;
  });
}

// Hints used by the demo radio (matches what a real drag would surface).
const DEMO_HINTS = {
  "drag-folder":   { folderCount: 1, imageCount: 0, otherCount: 0, folderName: "client-headshots" },
  "drag-files":    { folderCount: 0, imageCount: 12, otherCount: 0, folderName: "" },
  "drag-mixed":    { folderCount: 1, imageCount: 4, otherCount: 2, folderName: "campaign-assets" },
  "drag-blocked":  { folderCount: 0, imageCount: 0, otherCount: 3, folderName: "" },
};

const DEMO_INGEST = {
  folderName: "client-headshots",
  scanned: 47,
  found: 28,
  paths: [
    "client-headshots/anna_final_v3.heic",
    "client-headshots/raw/lukas_03.jpg",
    "client-headshots/raw/lukas_02.jpg",
    "client-headshots/_archive/2024/portrait_old.tif",
  ],
};

const DEMO_SUMMARY = {
  added: 28, skipped: 3, duped: 2, folderName: "client-headshots",
};

function App() {
  const [tweaks, setTweak] = useTweaks(TWEAK_DEFAULTS);
  useEffect(() => {
    document.documentElement.style.setProperty("--accent", tweaks.accent);
  }, [tweaks.accent]);

  const [files, setFiles] = useState(() => enrichFiles(SAMPLE_FILES));
  const [batches, setBatches] = useState(SAMPLE_BATCHES);
  const [selectedId, setSelectedId] = useState("f1");
  const [cfg, setCfg] = useState({
    bgKind: "none",
    bgColor: "#ffffff",
    format: "png",
    namePattern: "{name}_bgbgone",
    outDir: "~/Pictures/cutouts",
  });

  // Drop state
  const [dropPhase, setDropPhase] = useState("idle"); // idle | drag | ingest | summary
  const [dragHint, setDragHint] = useState(null);
  const [ingest, setIngest] = useState(null);
  const [summary, setSummary] = useState(null);

  // Reflect demo radio into drop state
  useEffect(() => {
    const d = tweaks.dropDemo;
    if (d === "idle") {
      setDropPhase("idle"); setDragHint(null); setIngest(null); setSummary(null);
    } else if (d === "drag-folder" || d === "drag-files" || d === "drag-mixed" || d === "drag-blocked") {
      setDropPhase("drag"); setDragHint(DEMO_HINTS[d]); setIngest(null); setSummary(null);
    } else if (d === "ingest") {
      setDropPhase("ingest"); setDragHint(null); setIngest(DEMO_INGEST); setSummary(null);
    } else if (d === "summary") {
      setDropPhase("summary"); setDragHint(null); setIngest(null); setSummary(DEMO_SUMMARY);
    } else if (d === "empty") {
      setFiles([]); setBatches([]); setSelectedId(null);
      setDropPhase("idle"); setDragHint(null); setIngest(null); setSummary(null);
    }
  }, [tweaks.dropDemo]);

  // Real drag handlers (on the window). Inspect dataTransfer.items to build a hint.
  useEffect(() => {
    function readHint(dt) {
      let folderCount = 0, imageCount = 0, otherCount = 0, folderName = "";
      const items = dt?.items;
      if (!items) return null;
      for (const it of items) {
        if (it.kind !== "file") continue;
        const entry = it.webkitGetAsEntry ? it.webkitGetAsEntry() : null;
        if (entry?.isDirectory) {
          folderCount++;
          if (!folderName) folderName = entry.name;
        } else {
          const t = it.type || "";
          if (t.startsWith("image/")) imageCount++;
          else otherCount++;
        }
      }
      return { folderCount, imageCount, otherCount, folderName };
    }
    function onDragEnter(e) {
      if (!e.dataTransfer?.types?.includes("Files")) return;
      e.preventDefault();
      const hint = readHint(e.dataTransfer) || { folderCount: 0, imageCount: 1, otherCount: 0, folderName: "" };
      setDragHint(hint);
      setDropPhase("drag");
    }
    function onDragOver(e) {
      if (e.dataTransfer?.types?.includes("Files")) e.preventDefault();
    }
    function onDragLeave(e) {
      if (e.relatedTarget === null) {
        setDropPhase("idle");
        setDragHint(null);
      }
    }
    function onDrop(e) {
      if (!e.dataTransfer?.types?.includes("Files")) return;
      e.preventDefault();
      // Demo: pretend to ingest, then summarize.
      setDropPhase("ingest");
      setIngest({ folderName: dragHint?.folderName || "dropped", scanned: 4, found: 2, paths: DEMO_INGEST.paths.slice(0,2) });
      let scanned = 4, found = 2, i = 0;
      const tick = setInterval(() => {
        scanned += 6 + Math.floor(Math.random() * 6);
        found += 3 + Math.floor(Math.random() * 4);
        i++;
        setIngest({
          folderName: dragHint?.folderName || "dropped",
          scanned, found,
          paths: DEMO_INGEST.paths.slice(0, Math.min(4, i + 1)),
        });
        if (i >= 4) {
          clearInterval(tick);
          setDropPhase("summary");
          setSummary({ added: found, skipped: 3, duped: 2, folderName: dragHint?.folderName || "dropped" });
          setIngest(null);
          setDragHint(null);
          setTimeout(() => setSummary(null), 6000);
        }
      }, 600);
    }
    window.addEventListener("dragenter", onDragEnter);
    window.addEventListener("dragover", onDragOver);
    window.addEventListener("dragleave", onDragLeave);
    window.addEventListener("drop", onDrop);
    return () => {
      window.removeEventListener("dragenter", onDragEnter);
      window.removeEventListener("dragover", onDragOver);
      window.removeEventListener("dragleave", onDragLeave);
      window.removeEventListener("drop", onDrop);
    };
  }, [dragHint]);

  const selectedFile = useMemo(() => files.find(f => f.id === selectedId), [files, selectedId]);

  function processAll() {
    setFiles(fs => fs.map(f => (f.state === "raw" || f.state === "error") ? { ...f, state: "queued" } : f));
  }

  function toggleBatch(batchId) {
    setBatches(bs => bs.map(b => b.id === batchId ? { ...b, collapsed: !b.collapsed } : b));
  }

  // Advance queue
  useEffect(() => {
    const t = setTimeout(() => {
      setFiles(fs => {
        const idx = fs.findIndex(f => f.state === "processing");
        if (idx >= 0) {
          const next = [...fs];
          next[idx] = { ...next[idx], state: "done", ms: 70 + Math.floor(Math.random() * 50) };
          return next;
        }
        const qidx = fs.findIndex(f => f.state === "queued");
        if (qidx >= 0) {
          const next = [...fs];
          next[qidx] = { ...next[qidx], state: "processing" };
          return next;
        }
        return fs;
      });
    }, 700);
    return () => clearTimeout(t);
  }, [files]);

  const pending = files.filter(f => f.state === "raw" || f.state === "error" || f.state === "queued" || f.state === "processing").length;
  const isEmpty = files.length === 0;

  return (
    <div className="window">
      <TitleBar pending={pending} onProcessAll={processAll}/>
      <DualView
        file={selectedFile}
        bgKind={cfg.bgKind}
        bgColor={cfg.bgColor}
        isEmpty={isEmpty}
        onPickFiles={() => {}}
        onPickFolder={() => {}}
      />
      <SelectedMeta file={selectedFile}/>
      <Config cfg={cfg} setCfg={setCfg}/>
      <FileList
        files={files}
        batches={batches}
        selectedId={selectedId}
        setSelectedId={setSelectedId}
        onCollapseBatch={toggleBatch}
        dragover={false}
        setDragover={() => {}}
        summary={summary}
        onDismissSummary={() => setSummary(null)}
        onShowSkipped={() => {}}
      />
      <StatusBar files={files} cfg={cfg}/>

      {dropPhase === "drag" && <DropVeil hint={dragHint}/>}
      {dropPhase === "ingest" && ingest && <IngestOverlay state={ingest}/>}

      <TweaksPanel title="Tweaks" subtitle="bgbgone">
        <TweakSection title="Drop-in demo">
          <TweakSelect
            label="Phase"
            value={tweaks.dropDemo}
            options={[
              { value: "idle", label: "Idle (default)" },
              { value: "empty", label: "Empty — first run" },
              { value: "drag-folder", label: "Drag: one folder" },
              { value: "drag-files", label: "Drag: many images" },
              { value: "drag-mixed", label: "Drag: folder + extras" },
              { value: "drag-blocked", label: "Drag: nothing usable" },
              { value: "ingest", label: "Ingesting folder" },
              { value: "summary", label: "Post-drop summary" },
            ]}
            onChange={(v) => setTweak("dropDemo", v)}
          />
        </TweakSection>
        <TweakSection title="Accent">
          <TweakColor
            label="Color"
            value={tweaks.accent}
            options={["#007aff", "#0a84ff", "#34c759", "#ff9500", "#bf5af2", "#202126"]}
            onChange={(v) => setTweak("accent", v)}
          />
        </TweakSection>
        <TweakSection title="Demo">
          <TweakButton label="Reset to fresh state" onClick={() => { setFiles(enrichFiles(SAMPLE_FILES).map(f => ({ ...f, state: "raw", ms: undefined }))); setBatches(SAMPLE_BATCHES); setSelectedId("f1"); }}/>
          <TweakButton label="Mark all done" onClick={() => setFiles(fs => fs.map(f => ({ ...f, state: "done", ms: 70 + Math.floor(Math.random() * 50) })))}/>
        </TweakSection>
      </TweaksPanel>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App/>);
