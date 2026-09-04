// Unwired component panel — the three wiring checks + the add command (07 §3.4, D20).
import React, { useState } from 'react';

const CHECKS = [
  { key: 'fixture', label: 'Fixture JSON', hint: 'capture/fixtures/compare/<group>/<Name>.json' },
  { key: 'adapter', label: 'Adapter registered', hint: 'capture/runners/compare/adapters/index.mjs' },
  { key: 'registry', label: 'ViewRegistry case', hint: 'iphone/MakeReadyCaptureTests/ViewRegistry.swift — case "component.<Name>"' },
];

export default function WiringChecklist({ detail }) {
  const [copied, setCopied] = useState(false);
  const cmd = detail.wiring?.addCommand ?? '';
  const copy = async () => {
    try { await navigator.clipboard.writeText(cmd); } catch { /* ignore */ }
    setCopied(true); setTimeout(() => setCopied(false), 1400);
  };
  return (
    <div className="cmp-cb-wiring">
      <div className="cmp-cb-col__title">Not capturable yet</div>
      <p className="cmp-cb-wiring__intro">
        <code>{detail.file}</code> isn’t wired into the capture harness. Wiring needs all three:
      </p>
      <ul className="cmp-cb-wiring__list">
        {CHECKS.map((c) => {
          const ok = !!detail.wiring && !detail.wiring.missing.includes(c.key);
          return (
            <li key={c.key} className={`cmp-cb-wiring__check${ok ? ' is-ok' : ''}`}>
              <span className="cmp-cb-wiring__mark">{ok ? '✓' : '✗'}</span>
              <span>
                <strong>{c.label}</strong>
                <span className="cmp-cb-wiring__hint">{c.hint}</span>
              </span>
            </li>
          );
        })}
      </ul>
      {cmd && (
        <button className="btn btn--primary" onClick={copy} title="Copy the wiring command for Claude">
          {copied ? 'Copied ✓' : cmd}
        </button>
      )}
    </div>
  );
}
