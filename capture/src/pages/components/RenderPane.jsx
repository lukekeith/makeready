// Column 3 — pan/zoom render + version timeline + recapture (07 §3.3/§3.4).
// The ZoomPane is the shared controlled viewer; this host owns view state (CR6).
import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import ZoomPane from '../../components/viewer/ZoomPane.jsx';
import VersionTimeline from './VersionTimeline.jsx';
import DevicePicker from './DevicePicker.jsx';
import WiringChecklist from './WiringChecklist.jsx';
import CaptureLogDock from './CaptureLogDock.jsx';

export default function RenderPane({
  detail, detailError, variant, viewport, onViewport,
  versionId, onSelectVersion, vdata, shotsVersion,
  capturing, log, onRecapture, commentApi,
  onHoverInspect, onClearInspect, hoverBox,
}) {
  const [view, setView] = useState({ scale: 1, cx: 0.5, cy: 0.5 });
  const [capMenuOpen, setCapMenuOpen] = useState(false);
  const capMenuRef = useRef(null);

  // Close the recapture split-button menu on outside click or Escape.
  useEffect(() => {
    if (!capMenuOpen) return;
    const onDown = (e) => { if (!capMenuRef.current?.contains(e.target)) setCapMenuOpen(false); };
    const onKey = (e) => { if (e.key === 'Escape') setCapMenuOpen(false); };
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey);
    return () => { document.removeEventListener('mousedown', onDown); document.removeEventListener('keydown', onKey); };
  }, [capMenuOpen]);
  const [hover, setHover] = useState(null);
  const [natural, setNatural] = useState({ iphone: null });
  const resetView = useCallback(() => setView({ scale: 1, cx: 0.5, cy: 0.5 }), []);
  useEffect(() => { resetView(); setNatural({ iphone: null }); }, [vdata?.versionId, viewport, resetView]);
  const onNatural = useCallback((platform, dims) => setNatural((n) => (n[platform] && n[platform].w === dims.w && n[platform].h === dims.h ? n : { ...n, [platform]: dims })), []);

  // Host-owned "0 = fit" key (CR6; `c`/Esc live in ComponentsLayout).
  useEffect(() => {
    const onKey = (e) => {
      const el = e.target;
      const typing = el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.isContentEditable);
      if (!typing && e.key === '0') resetView();
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [resetView]);

  const numberOf = useMemo(() => {
    const m = new Map();
    [...(commentApi.comments ?? [])].sort((a, b) => (a.createdAt < b.createdAt ? -1 : 1)).forEach((c, i) => m.set(c.id, i + 1));
    return m;
  }, [commentApi.comments]);

  if (detailError) return <div className="cmp-cb-col cmp-cb-col--render"><div className="error-banner">{detailError}</div></div>;
  if (!detail) return <div className="cmp-cb-col cmp-cb-col--render"><div className="cmp-cb-col__empty">Select a component and variant</div></div>;
  if (!detail.variants?.length && detail.wiring) {
    return <div className="cmp-cb-col cmp-cb-col--render"><WiringChecklist detail={detail} /></div>;
  }
  if (!variant) return <div className="cmp-cb-col cmp-cb-col--render"><div className="cmp-cb-col__empty">Select a variant</div></div>;

  const isCurrent = versionId === null;
  const shotUrl = vdata?.shot ? `${vdata.shot}?v=${shotsVersion}` : null;

  const commentProps = {
    // Only the VIEWED version's pins render on the canvas (07 §3.3); the
    // Comments tab still lists every version's threads.
    comments: (commentApi.comments ?? []).filter((c) => c.onThisVersion),
    numberOf,
    draft: commentApi.draftPin,
    onPlace: commentApi.placeDraft,
    onSubmitDraft: commentApi.submitDraft,
    onCancelDraft: commentApi.cancelDraft,
    selectedId: commentApi.selectedCommentId,
    onSelect: commentApi.setSelectedCommentId,
    canEdit: commentApi.canComment,
    onReply: commentApi.onReply,
    onResolve: commentApi.onResolve,
    onDelete: commentApi.onDelete,
    hoverBox,
  };

  return (
    <div className="cmp-cb-col cmp-cb-col--render">
      <div className="cmp-cb-render__bar">
        <span className="cmp-cb-render__title">{detail.name} · {variant.name}</span>
        {!isCurrent && <span className="cmp-cb-render__oldchip">viewing old version</span>}
        <DevicePicker viewports={detail.viewports} selected={viewport} onSelect={onViewport} />
        {detail.canCapture && (
          <>
            <button
              className={`btn cmp-icon-btn${commentApi.commentMode ? ' btn--primary' : ''}`}
              disabled={!commentApi.canComment}
              onClick={() => { commentApi.setCommentMode(!commentApi.commentMode); commentApi.cancelDraft(); }}
              title='Comment mode — click the render to drop a pin ("c")'
            >
              {commentApi.commentMode ? 'Commenting…' : 'Comment'}
            </button>
            <div className="cmp-capsplit" ref={capMenuRef}>
              <button className="btn btn--primary cmp-capsplit__main" onClick={() => onRecapture()} disabled={capturing}>
                {capturing ? 'Capturing…' : 'Recapture'}
              </button>
              <button
                className="btn btn--primary cmp-capsplit__caret"
                onClick={() => setCapMenuOpen((o) => !o)}
                disabled={capturing}
                aria-haspopup="menu"
                aria-expanded={capMenuOpen}
                title="Recapture options"
              >
                <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                  <polyline points="6 9 12 15 18 9" />
                </svg>
              </button>
              {capMenuOpen && (
                <div className="cmp-capsplit__menu" role="menu">
                  <button className="cmp-capsplit__item" role="menuitem" onClick={() => { setCapMenuOpen(false); onRecapture(); }}>
                    <span className="cmp-capsplit__item-name">Recapture variant</span>
                    <span className="cmp-capsplit__item-sub">{variant.name}</span>
                  </button>
                  <button className="cmp-capsplit__item" role="menuitem" onClick={() => { setCapMenuOpen(false); onRecapture({ allVariants: true }); }}>
                    <span className="cmp-capsplit__item-name">Recapture all variants</span>
                    <span className="cmp-capsplit__item-sub">{detail.variants?.length ? `${detail.variants.length} total` : 'whole component'}</span>
                  </button>
                </div>
              )}
            </div>
          </>
        )}
      </div>

      {shotUrl ? (
        <div className="cmp-cb-render__pane">
          <ZoomPane
            platform="iphone"
            label={isCurrent ? 'Current render' : `Version ${vdata?.versionId?.slice(-6) ?? ''}`}
            url={shotUrl}
            viewport={viewport}
            captured
            natural={natural.iphone}
            fallbackNatural={detail.viewportDimensions?.[viewport]}
            onNatural={onNatural}
            onReset={resetView}
            view={view}
            setView={setView}
            hover={hover}
            setHover={setHover}
            capturing={capturing}
            commentMode={commentApi.commentMode}
            onHoverInspect={onHoverInspect}
            onClearInspect={onClearInspect}
            {...commentProps}
          />
        </div>
      ) : (
        <div className="cmp-cb-col__empty">
          never captured
          {detail.canCapture && <div style={{ marginTop: 10 }}><button className="btn btn--primary" onClick={() => onRecapture()} disabled={capturing}>{capturing ? 'Capturing…' : 'Capture now'}</button></div>}
        </div>
      )}

      <VersionTimeline
        versions={variant.versions ?? []}
        selectedId={versionId}
        onSelect={onSelectVersion}
        shotsVersion={shotsVersion}
      />

      {(capturing || log.length > 0) && <CaptureLogDock lines={log} capturing={capturing} viewportLabel={viewport} />}
    </div>
  );
}
