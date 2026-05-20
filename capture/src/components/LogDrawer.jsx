import React, { useContext, useEffect, useRef, useState } from 'react';
import { CaptureContext } from '../App.jsx';
import { subscribeCapture } from '../api.js';

function classifyLine(line) {
  if (typeof line !== 'string') return '';
  if (line.startsWith('→')) return 'drawer__line--start';
  if (line.includes('✓')) return 'drawer__line--ok';
  if (line.includes('✗') || line.toLowerCase().includes('error')) return 'drawer__line--err';
  return '';
}

export default function LogDrawer() {
  const { activeRun, setActiveRun, bumpCapturesVersion, drawerVisible: visible, setDrawerVisible: setVisible } = useContext(CaptureContext);
  const [lines, setLines] = useState([]);
  const [summary, setSummary] = useState(null); // { code, durationMs }
  const logRef = useRef(null);

  useEffect(() => {
    if (!activeRun) return;
    setLines([]);
    setSummary(null);
    setVisible(true);
    const close = subscribeCapture(activeRun.runId, {
      onLine: (line) => setLines((prev) => [...prev, line]),
      onDone: (data) => {
        setSummary(data);
        bumpCapturesVersion();
        if (data?.code === 0) {
          // Auto-hide after a clean finish; leave open on error.
          setTimeout(() => {
            setVisible(false);
            setActiveRun(null);
          }, 2500);
        }
      },
      onError: () => {
        setSummary({ code: -1 });
      },
    });
    return close;
  }, [activeRun, bumpCapturesVersion, setActiveRun]);

  useEffect(() => {
    if (logRef.current) logRef.current.scrollTop = logRef.current.scrollHeight;
  }, [lines]);

  const scopeLabel =
    activeRun?.scope === 'all'
      ? 'all workflows'
      : activeRun?.target
        ? activeRun.target
        : activeRun?.scope ?? '';

  return (
    <div className={`drawer${visible ? ' drawer--open' : ''}`}>
      <div className="drawer__head">
        <div className="drawer__title">
          capture: {scopeLabel}
          {summary && (
            <span style={{ marginLeft: 10 }}>
              {summary.code === 0
                ? `✓ done in ${Math.round((summary.durationMs ?? 0) / 100) / 10}s`
                : `✗ exit ${summary.code}`}
            </span>
          )}
        </div>
        <button
          className="btn"
          style={{ padding: '4px 10px' }}
          onClick={() => {
            setVisible(false);
            // Only clear activeRun if the capture is finished;
            // hiding the drawer mid-capture should not abort it.
            if (summary) setActiveRun(null);
          }}
        >
          {summary ? 'Close' : 'Hide'}
        </button>
      </div>
      <div className="drawer__log" ref={logRef}>
        {lines.map((line, i) => (
          <div key={i} className={`drawer__line ${classifyLine(line)}`}>
            {line || '\u00A0'}
          </div>
        ))}
        {summary && (
          <div className="drawer__line drawer__line--done">
            {summary.code === 0
              ? `Done (${Math.round((summary.durationMs ?? 0) / 100) / 10}s).`
              : `Failed (exit code ${summary.code}).`}
          </div>
        )}
      </div>
    </div>
  );
}
