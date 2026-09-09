// Column 4 — Comments plus the era's own tabs (07 §3.5).
//
// 1.0: Comments + Data (the fixture that produced the render).
// 2.0: Details + Comments + Contract, plus Data once the row is BUILT — a
// specced-only row has no fixture to edit and its truth is purely the spec, but
// a built one renders from capture/fixtures/ui2/C-###.json exactly the way a
// 1.0 component renders from its own fixture, so the same editor applies.
// Contract describes the whole component, Details narrows to what the SELECTED
// STATE sets per the spec, and Data is what that state actually rendered with.
import React, { useState } from 'react';
import CommentsTab from './CommentsTab.jsx';
import DataEditor from './DataEditor.jsx';
import Ui2ContractTab from './Ui2ContractTab.jsx';
import Ui2DetailsTab from './Ui2DetailsTab.jsx';

const TAB_LABEL = { details: 'Details', comments: 'Comments', contract: 'Contract', data: 'Data' };

export default function SidePanel({ detail, variant, activeVersionId, currentVersionId, onSelectVersion, commentApi, onSaveFixture, dataView = null, mode = 'code' }) {
  const [tab, setTab] = useState('comments');
  const ready = !!detail && !!variant;
  // Details sits left of Comments (2.0 only); Comments stays the default tab.
  // Data appears on the 2.0 side only for a built row — there is no fixture to
  // show otherwise.
  const tabs = mode === 'design'
    ? ['details', 'comments', 'contract', ...(detail?.built ? ['data'] : [])]
    : ['comments', 'data'];
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
      {ready && tab === 'data' && mode !== 'design' && (
        <DataEditor
          key={`${detail.path}::${variant.name}`}
          shared={variant.shared}
          canEdit={!!detail.canCapture && !!detail.fixtureFile}
          onSave={onSaveFixture}
        />
      )}
      {/* 2.0: a state with no fixture entry is not an empty object — it is a
          state the build deliberately skipped (an `undesigned` row, or one the
          contract marks `n/a`), so say which rather than offering an editor
          whose Save would have nowhere to land. */}
      {ready && tab === 'data' && mode === 'design' && (
        dataView
          ? (
            <DataEditor
              // Keyed on the VERSION too: switching captures must reset the
              // editor's draft, or the previous version's edits would appear to
              // belong to the newly selected one.
              key={`${detail.id}::${variant.name}::${activeVersionId ?? 'current'}`}
              shared={dataView.props}
              optionsByKey={dataView.optionsByKey}
              assetsByKey={dataView.assetsByKey}
              readOnly={!dataView.editable}
              note={dataView.note}
              hint={dataView.hint}
              canEdit={!!detail.canCapture && !!detail.fixtureFile}
              onSave={onSaveFixture}
            />
          )
          : (
            <div className="cmp-cb-col__empty">
              This state has no fixture entry — it was skipped by the build
              {variant.consumptionState === 'undesigned' ? ' as undesigned' : ''}, so there is
              nothing rendered and nothing to edit.
            </div>
          )
      )}
    </div>
  );
}
