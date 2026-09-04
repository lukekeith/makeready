// Column 4 — Comments / Data tab panel. Phase 2 placeholder shell; the comment
// threads + recursive data editor land in Phase 3 (12-phase-3 doc).
import React, { useState } from 'react';

export default function SidePanel({ detail, variant }) {
  const [tab, setTab] = useState('comments');
  return (
    <div className="cmp-cb-col cmp-cb-col--side">
      <div className="cmp-tab-switch">
        {['comments', 'data'].map((t) => (
          <button key={t} className={`cmp-tab-switch__btn${tab === t ? ' cmp-tab-switch__btn--active' : ''}`} onClick={() => setTab(t)}>
            {t === 'comments' ? 'Comments' : 'Data'}
          </button>
        ))}
      </div>
      <div className="cmp-cb-col__empty">
        {!detail || !variant ? 'Select a component and variant' : `${tab === 'comments' ? 'Comments' : 'Data editor'} arrive in Phase 3`}
      </div>
    </div>
  );
}
