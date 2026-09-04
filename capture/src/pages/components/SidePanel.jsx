// Column 4 — Comments / Data tab panel (07 §3.5).
import React, { useState } from 'react';
import CommentsTab from './CommentsTab.jsx';
import DataEditor from './DataEditor.jsx';

export default function SidePanel({ detail, variant, activeVersionId, currentVersionId, onSelectVersion, commentApi, onSaveFixture }) {
  const [tab, setTab] = useState('comments');
  const ready = !!detail && !!variant;
  return (
    <div className="cmp-cb-col cmp-cb-col--side">
      <div className="cmp-tab-switch">
        {['comments', 'data'].map((t) => (
          <button key={t} className={`cmp-tab-switch__btn${tab === t ? ' cmp-tab-switch__btn--active' : ''}`} onClick={() => setTab(t)}>
            {t === 'comments' ? 'Comments' : 'Data'}
          </button>
        ))}
      </div>
      {!ready && <div className="cmp-cb-col__empty">Select a component and variant</div>}
      {ready && tab === 'comments' && (
        <CommentsTab
          commentApi={commentApi}
          activeVersionId={activeVersionId}
          currentVersionId={currentVersionId}
          onSelectVersion={onSelectVersion}
        />
      )}
      {ready && tab === 'data' && (
        <DataEditor
          key={`${detail.path}::${variant.name}`}
          shared={variant.shared}
          canEdit={!!detail.canCapture && !!detail.fixtureFile}
          onSave={onSaveFixture}
        />
      )}
    </div>
  );
}
