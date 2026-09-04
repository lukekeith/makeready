// Docked capture log (CR7 — NEW, copying /compare's inline cmp-log--docked
// pattern from CompareDetail.jsx; /compare keeps its own inline block).
import React from 'react';

export default function CaptureLogDock({ lines, capturing, viewportLabel }) {
  return (
    <div className="cmp-log cmp-log--docked">
      <div className="cmp-log__head">
        {capturing ? <><span className="layout__activity-spinner" /> Capturing {viewportLabel}…</> : 'Last capture log'}
      </div>
      <pre className="cmp-log__body">{lines.join('\n') || '…'}</pre>
    </div>
  );
}
