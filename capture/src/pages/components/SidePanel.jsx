// Column 4 — Comments plus the era's own tabs (07 §3.5).
//
// 1.0: Comments + Data (the fixture that produced the render).
// 2.0: Details + Comments + Contract — a 2.0 component has no fixture to edit,
// and its truth is the spec: Contract describes the whole component, Details
// narrows to what the SELECTED STATE sets.
import React, { useState } from 'react';
import CommentsTab from './CommentsTab.jsx';
import DataEditor from './DataEditor.jsx';
import Ui2ContractTab from './Ui2ContractTab.jsx';
import Ui2DetailsTab from './Ui2DetailsTab.jsx';

const TAB_LABEL = { details: 'Details', comments: 'Comments', contract: 'Contract', data: 'Data' };

export default function SidePanel({ detail, variant, activeVersionId, currentVersionId, onSelectVersion, commentApi, onSaveFixture, mode = 'code' }) {
  const [tab, setTab] = useState('comments');
  const ready = !!detail && !!variant;
  // Details sits left of Comments (2.0 only); Comments stays the default tab.
  const tabs = mode === 'design' ? ['details', 'comments', 'contract'] : ['comments', 'data'];
  return (
    <div className="cmp-cb-col cmp-cb-col--side">
      <div className="cmp-tab-switch">
        {tabs.map((t) => (
          <button key={t} className={`cmp-tab-switch__btn${tab === t ? ' cmp-tab-switch__btn--active' : ''}`} onClick={() => setTab(t)}>
            {TAB_LABEL[t]}
          </button>
        ))}
      </div>
      {/* Details is the one tab with something to say when a row has no states
          at all — an unspecced row's whole point is that nothing is set yet. */}
      {!ready && tab !== 'details' && <div className="cmp-cb-col__empty">Select a component and variant</div>}
      {!ready && tab === 'details' && detail && <Ui2DetailsTab detail={detail} variant={null} />}
      {ready && tab === 'comments' && (
        <CommentsTab
          commentApi={commentApi}
          activeVersionId={activeVersionId}
          currentVersionId={currentVersionId}
          onSelectVersion={onSelectVersion}
        />
      )}
      {ready && tab === 'details' && <Ui2DetailsTab detail={detail} variant={variant} />}
      {ready && tab === 'contract' && <Ui2ContractTab detail={detail} variant={variant} />}
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
