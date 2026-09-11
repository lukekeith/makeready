// Column 4 — Comments plus the era's own tabs (07 §3.5).
//
// 1.0: Comments + Data (the fixture that produced the render).
// 2.0: Details + Comments + Contract, plus Data and Layout once the row is
// BUILT — a specced-only row has no fixture to edit and its truth is purely the
// spec, but a built one renders from capture/fixtures/ui2/C-###.json exactly the
// way a 1.0 component renders from its own fixture, so the same editor applies.
// Contract describes the whole component, Details narrows to what the SELECTED
// STATE sets per the spec, Data is what that state actually rendered with, and
// Layout is the geometry that rendering produced.
import React, { useState } from 'react';
import CommentsTab from './CommentsTab.jsx';
import DataEditor from './DataEditor.jsx';
import Ui2ContractTab from './Ui2ContractTab.jsx';
import Ui2DetailsTab from './Ui2DetailsTab.jsx';
import Ui2LayoutTab from './Ui2LayoutTab.jsx';
import Ui2ScreenTab from './Ui2ScreenTab.jsx';

const TAB_LABEL = { details: 'Details', comments: 'Comments', contract: 'Contract', data: 'Data', layout: 'Layout', screen: 'Screen' };

export default function SidePanel({
  detail, variant, activeVersionId, currentVersionId, onSelectVersion, commentApi, onSaveFixture,
  dataView = null, mode = 'code', elements = null, platform = null, onInspect = null,
}) {
  const [tab, setTab] = useState('comments');
  const ready = !!detail && !!variant;
  // A SCREEN has no contract doc, no props and no fixture — its spec IS the
  // whole of what the panel can say — so it gets the Screen tab in place of
  // Details/Contract rather than three tabs where two would be empty.
  const isScreen = detail?.kind === 'screen';
  // Details sits left of Comments (2.0 only); Comments stays the default tab.
  // Data appears on the 2.0 side only for a built row — there is no fixture to
  // show otherwise.
  const tabs = mode === 'design'
    ? (isScreen
      ? ['screen', 'comments']
      : ['details', 'comments', 'contract', ...(detail?.built ? ['data', 'layout'] : [])])
    : ['comments', 'data'];
  // Selecting a screen while Contract/Data is showing would land on a tab that
  // no longer exists and render nothing at all.
  const activeTab = tabs.includes(tab) ? tab : 'comments';
  return (
    <div className="cmp-cb-col cmp-cb-col--side">
      <div className={`cmp-tab-switch${tabs.length > 4 ? ' cmp-tab-switch--tight' : ''}`}>
        {tabs.map((t) => (
          <button key={t} className={`cmp-tab-switch__btn${activeTab === t ? ' cmp-tab-switch__btn--active' : ''}`} onClick={() => setTab(t)}>
            {TAB_LABEL[t]}
          </button>
        ))}
      </div>
      {/* Details is the one tab with something to say when a row has no states
          at all — an unspecced row's whole point is that nothing is set yet. */}
      {!ready && activeTab !== 'details' && activeTab !== 'screen' && <div className="cmp-cb-col__empty">Select a component and variant</div>}
      {!ready && activeTab === 'details' && detail && <Ui2DetailsTab detail={detail} variant={null} />}
      {!ready && activeTab === 'screen' && detail && <Ui2ScreenTab detail={detail} variant={null} />}
      {ready && activeTab === 'comments' && (
        <CommentsTab
          commentApi={commentApi}
          activeVersionId={activeVersionId}
          currentVersionId={currentVersionId}
          onSelectVersion={onSelectVersion}
        />
      )}
      {ready && activeTab === 'details' && <Ui2DetailsTab detail={detail} variant={variant} />}
      {ready && activeTab === 'screen' && <Ui2ScreenTab detail={detail} variant={variant} />}
      {ready && activeTab === 'contract' && <Ui2ContractTab detail={detail} variant={variant} />}
      {/* Keyed on the VERSION as well as the state: each capture has its own
          element map, so switching versions must rebuild the tree and drop the
          selection rather than point at a part from the previous render. */}
      {ready && activeTab === 'layout' && (
        <Ui2LayoutTab
          key={`${detail.id}::${variant.name}::${activeVersionId ?? 'current'}`}
          detail={detail}
          elements={elements}
          platform={platform}
          onInspect={onInspect}
        />
      )}
      {ready && activeTab === 'data' && mode !== 'design' && (
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
      {ready && activeTab === 'data' && mode === 'design' && (
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
