// Column 3 — pan/zoom render + version timeline + recapture (07 §3.3/§3.4).
// The ZoomPane is the shared controlled viewer; this host owns view state (CR6).
//
// Era-agnostic: 1.0 renders a captured iPhone screenshot (platform `iphone`),
// 2.0 renders the frozen Figma snapshot (platform `design`). Only the labels,
// the empty state and the split-button menu differ — passed in by the host so
// this pane stays one component for both.
import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import ZoomPane from '../../components/viewer/ZoomPane.jsx';
import { copyToClipboard } from '../../util/clipboard.js';
import VersionTimeline from './VersionTimeline.jsx';
import DevicePicker from './DevicePicker.jsx';
import WiringChecklist from './WiringChecklist.jsx';
import CaptureLogDock from './CaptureLogDock.jsx';

export default function RenderPane({
  detail, detailError, variant, viewport, onViewport,
  versionId, onSelectVersion, vdata, shotsVersion,
  capturing, log, onRecapture, commentApi,
  onHoverInspect, onClearInspect, hoverBox, inspectBox = null,
  // Component targeting on a 2.0 screen — pass-through only (suite 07 §4.2).
  onHoverTarget, onClearTarget, onSelectTarget, componentBox = null,
  componentSelectedBoxes = null, componentPreviewBoxes = null,
  platform = 'iphone', emptyState = null, allVariants = true, labels = {},
  platforms = null, onPlatform = null, activeShot = null, onDeleteVersion = null,
  // Render tabs (2.0 only). `tabs` is the EXTRA tabs the host has opened — the
  // page's own render is tab 0 and is synthesised here, because only this pane
  // knows the label, url and platform that describe it. A tab carries everything
  // needed to draw it (`url`, optional `boxes`), so a tab survives the side pane
  // that opened it being closed: nothing is re-fetched to keep one alive.
  tabs = [], activeTabKey = null, onSelectTab = null, onCloseTab = null,
  // Green hover boxes for a borrowed tab (the screen pane's schema rows), and a
  // request to frame one rect on it.
  tabPreviewBoxes = null, zoomTo = null,
  // The Prompt menu's contents, supplied by the host: [{ label, sub?, text }] — or
  // [{ label, sub?, action }] for an entry that OPENS something instead of copying. The text
  // is what lands on the clipboard. Host-supplied rather than built here because the command
  // that resolves a comment differs per era — 1.0 edits the Swift component
  // (`/component-resolve`), 2.0 edits the preview view against its Figma snapshot
  // (`/ui2-resolve`) — and only the host knows which it is. Empty ⇒ no button.
  //
  // `action` exists for commands that must not be copyable in one click. Merge is the case:
  // it strikes a registry row out of the program and its argument ORDER decides which row
  // dies, so the host opens a dialog that makes both sides explicit rather than handing over
  // a pre-built string (see Ui2MergeDialog).
  prompts = [],
}) {
  const text = {
    recapture: 'Recapture',
    busy: 'Capturing…',
    variantItem: 'Recapture variant',
    allItem: 'Recapture all variants',
    // Sub-line under the "all" menu item. Null = derive it from the variant
    // count; a host whose "all" doesn't mean every listed variant (2.0 skips
    // undesigned states) passes its own count instead.
    allItemSub: null,
    empty: 'never captured',
    emptyAction: 'Capture now',
    current: 'Current render',
    ...labels,
  };
  const [view, setView] = useState({ scale: 1, cx: 0.5, cy: 0.5 });
  const [capMenuOpen, setCapMenuOpen] = useState(false);
  const capMenuRef = useRef(null);
  const [promptMenuOpen, setPromptMenuOpen] = useState(false);
  const [copiedPrompt, setCopiedPrompt] = useState(null);
  const promptMenuRef = useRef(null);

  // Close the recapture split-button menu on outside click or Escape.
  useEffect(() => {
    if (!capMenuOpen) return;
    const onDown = (e) => { if (!capMenuRef.current?.contains(e.target)) setCapMenuOpen(false); };
    const onKey = (e) => { if (e.key === 'Escape') setCapMenuOpen(false); };
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey);
    return () => { document.removeEventListener('mousedown', onDown); document.removeEventListener('keydown', onKey); };
  }, [capMenuOpen]);
  // Close the Prompt menu on outside click or Escape (mirrors the capture menu above).
  useEffect(() => {
    if (!promptMenuOpen) return;
    const onDown = (e) => { if (!promptMenuRef.current?.contains(e.target)) setPromptMenuOpen(false); };
    const onKey = (e) => { if (e.key === 'Escape') setPromptMenuOpen(false); };
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey);
    return () => { document.removeEventListener('mousedown', onDown); document.removeEventListener('keydown', onKey); };
  }, [promptMenuOpen]);

  const copyPrompt = async (entry) => {
    // An `action` entry never touches the clipboard — it hands off to the host and closes.
    if (entry.action) { setPromptMenuOpen(false); entry.action(); return; }
    await copyToClipboard(entry.text);
    setCopiedPrompt(entry.text);
    setPromptMenuOpen(false);
    setTimeout(() => setCopiedPrompt((t) => (t === entry.text ? null : t)), 1400);
  };

  const [hover, setHover] = useState(null);
  const [natural, setNatural] = useState({});
  const resetView = useCallback(() => setView({ scale: 1, cx: 0.5, cy: 0.5 }), []);
  // Natural dimensions are a property of the IMAGE, so they are re-measured whenever the
  // displayed render can change — a different version, a different device.
  useEffect(() => { setNatural({}); }, [vdata?.versionId, viewport]);
  // Pan/zoom is per COMPONENT, not per variant or version. Switching states (or stepping back
  // through the timeline) inside one component keeps the viewer parked exactly where it was,
  // which is what makes "is this inset the same in every state?" answerable by flipping between
  // them. It resets when the component itself changes, and on a device change, whose render has
  // different pixel dimensions under the same normalised (cx, cy).
  // The active tab is in here as well: a different tab is a different image with
  // its own aspect, so it has to be refitted rather than inheriting the previous
  // one's pan — which is exactly the case the per-component rule above is NOT.
  useEffect(() => { resetView(); }, [detail?.id, viewport, activeTabKey, resetView]);

  // Frame one rect of the image. The rect is in image fractions, so the centre is
  // the view's `cx/cy` directly; the scale is derived from the rect's own size
  // rather than from measured pixels — this pane never learns the viewport's
  // dimensions (ZoomPane measures them), and a fraction-based zoom lands the same
  // way at any column width. 0.4 = let the box occupy about 40% of the fitted
  // view, which reads as "zoomed in on this" without losing its surroundings.
  useEffect(() => {
    if (!zoomTo?.rect) return;
    const { x, y, w, h } = zoomTo.rect;
    const scale = Math.max(1, Math.min(8, 0.4 / Math.max(w, h, 0.001)));
    setView({ scale, cx: x + w / 2, cy: y + h / 2 });
  }, [zoomTo]);
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
  if (!detail.variants?.length && (emptyState || detail.wiring)) {
    return <div className="cmp-cb-col cmp-cb-col--render">{emptyState ?? <WiringChecklist detail={detail} />}</div>;
  }
  if (!variant) return <div className="cmp-cb-col cmp-cb-col--render"><div className="cmp-cb-col__empty">Select a variant</div></div>;

  const isCurrent = versionId === null;
  // `activeShot` (host-computed, 2.0 dual-render only) names the screenshot
  // ACTUALLY being displayed for the toggle's current selection — which can
  // differ from `platform` when this version has no shot for that platform yet
  // (an older version captured before the component was built) and the host
  // fell back to the design shot. Everything downstream (the image, its natural
  // dims, comment pins) keys off the SHOWN platform, not the raw toggle value,
  // so a fallback never gets mislabeled as the real thing. 1.0 never passes
  // `activeShot`, so `shown` collapses to the old `vdata.shot` behavior.
  const shown = activeShot ?? { url: vdata?.shot ?? null, screenshotId: vdata?.screenshotId ?? null, platform, fallback: false };
  const selfShotUrl = shown.url ? `${shown.url}?v=${shotsVersion}` : null;
  const selfLabel = isCurrent ? text.current : `Version ${vdata?.versionId?.slice(-6) ?? ''}`;

  // Tab 0 is the page's own render. It is built here rather than by the host
  // because only this pane knows the label, the url and the fallback the version
  // toggle resolved to — and it is never closable, since closing it would leave
  // the viewer with nothing to show.
  const selfTab = {
    key: 'self',
    kind: 'self',
    title: detail.name,
    subtitle: selfLabel,
    closable: false,
  };
  // The strip is ALWAYS drawn, even when the page's own render is the only tab.
  // A head that shows a plain title until you open something and then turns into
  // a tab strip changes shape under you; one tab that gains neighbours does not,
  // and it says up front that this area can hold more than one render.
  const allTabs = [selfTab, ...tabs];
  const active = allTabs.find((t) => t.key === activeTabKey) ?? selfTab;
  const onSelf = active.kind === 'self';

  // What the viewport actually shows. A borrowed tab brings its own image and its
  // own boxes; the page's own render keeps every behaviour it had.
  const shotUrl = onSelf ? selfShotUrl : (active.url ?? null);
  // Keyed per tab so each image's measured dimensions are cached separately —
  // sharing one key made a screen frame inherit the component's aspect for a
  // frame before correcting itself.
  const shownPlatform = onSelf ? shown.platform : active.key;

  // Comments belong to the PAGE's render, so a borrowed tab shows none: a pin
  // placed on C-035's snapshot would otherwise appear to sit on members-home's
  // frame simply because both are on screen. Comment mode is suppressed the same
  // way at the call site (the Comment button is hidden while a tab is active),
  // and so are hit-testing and click-to-select — those read the PAGE's element
  // map, so a borrowed tab is a picture to look at, not a surface to select on.
  const commentProps = !onSelf ? {
    comments: [],
    numberOf,
    draft: null,
    canEdit: false,
    // The one thing a borrowed tab DOES draw: the focused component's instances,
    // in the same weight the screen page uses for a selected component.
    componentSelectedBoxes: active.boxes ?? null,
    componentPreviewBoxes: tabPreviewBoxes,
  } : {
    // Only the VIEWED version's pins render on the canvas (07 §3.3); the
    // Comments tab still lists every version's threads. A pin also carries the
    // platform it was placed on — filter to the platform actually on screen so
    // a Figma-anchored pin never appears to sit on the built render (or vice
    // versa) just because both live on the same version.
    comments: (commentApi.comments ?? []).filter((c) => c.onThisVersion && c.platform === shown.platform),
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
    inspectBox,
    componentBox,
    componentSelectedBoxes,
    componentPreviewBoxes,
  };

  return (
    <div className="cmp-cb-col cmp-cb-col--render">
      <div className="cmp-cb-render__bar">
        <span className="cmp-cb-render__title">{detail.name} · {variant.name}</span>
        {!isCurrent && <span className="cmp-cb-render__oldchip">viewing old version</span>}
        <DevicePicker viewports={detail.viewports} selected={viewport} onSelect={onViewport} />
        {platforms?.length > 1 && onPlatform && onSelf && (
          <div className="cmp-render__platforms">
            {platforms.map((p) => (
              <button
                key={p}
                className={`cmp-render__platform${p === platform ? ' is-active' : ''}`}
                onClick={() => onPlatform(p)}
              >{p === 'design' ? 'Figma' : 'Built'}</button>
            ))}
          </div>
        )}
        {detail.canCapture && onSelf && (
          <>
            <button
              className={`btn cmp-icon-btn${commentApi.commentMode ? ' btn--primary' : ''}`}
              disabled={!commentApi.canComment}
              onClick={() => { commentApi.setCommentMode(!commentApi.commentMode); commentApi.cancelDraft(); }}
              title='Comment mode — click the render to drop a pin ("c")'
            >
              {commentApi.commentMode ? 'Commenting…' : 'Comment'}
            </button>
          </>
        )}

        {prompts.length > 0 && (
          <div className="cmp-capsplit cmp-capsplit--prompt" ref={promptMenuRef}>
            {/* Same split-button structure as the capture button beside it — main half +
                divided caret half — so the two read as one control family. The only
                difference is colour: this one is the neutral `btn`, that one `btn--primary`.
                Both halves open the menu here, because unlike capture there is no primary
                action to put on the main half: every prompt lives in the menu. */}
            <button
              className="btn cmp-capsplit__main"
              onClick={() => setPromptMenuOpen((o) => !o)}
              aria-haspopup="menu"
              aria-expanded={promptMenuOpen}
              title="Copy a prompt for this component"
            >
              {copiedPrompt ? 'Copied!' : 'Prompt'}
            </button>
            <button
              className="btn cmp-capsplit__caret"
              onClick={() => setPromptMenuOpen((o) => !o)}
              aria-haspopup="menu"
              aria-expanded={promptMenuOpen}
              title="Prompt options"
            >
              <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                <polyline points="6 9 12 15 18 9" />
              </svg>
            </button>
            {promptMenuOpen && (
              <div className="cmp-capsplit__menu cmp-capsplit__menu--prompts" role="menu">
                {prompts.map((entry) => (
                  <button
                    key={entry.text ?? entry.label}
                    className="cmp-capsplit__item"
                    role="menuitem"
                    onClick={() => copyPrompt(entry)}
                  >
                    <span className="cmp-capsplit__item-name">{entry.label}</span>
                    <span className="cmp-capsplit__item-sub">{entry.sub ?? entry.text}</span>
                  </button>
                ))}
              </div>
            )}
          </div>
        )}

        {detail.canCapture && (
          <>
            <div className="cmp-capsplit" ref={capMenuRef}>
              <button className="btn btn--primary cmp-capsplit__main" onClick={() => onRecapture()} disabled={capturing}>
                {capturing ? text.busy : text.recapture}
              </button>
              {allVariants && (
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
              )}
              {allVariants && capMenuOpen && (
                <div className="cmp-capsplit__menu" role="menu">
                  <button className="cmp-capsplit__item" role="menuitem" onClick={() => { setCapMenuOpen(false); onRecapture(); }}>
                    <span className="cmp-capsplit__item-name">{text.variantItem}</span>
                    <span className="cmp-capsplit__item-sub">{variant.name}</span>
                  </button>
                  <button className="cmp-capsplit__item" role="menuitem" onClick={() => { setCapMenuOpen(false); onRecapture({ allVariants: true }); }}>
                    <span className="cmp-capsplit__item-name">{text.allItem}</span>
                    <span className="cmp-capsplit__item-sub">{text.allItemSub ?? (detail.variants?.length ? `${detail.variants.length} total` : 'whole component')}</span>
                  </button>
                </div>
              )}
            </div>
          </>
        )}
      </div>

      {shown.fallback && (
        <div className="cmp-cb-render__notice">
          <span
            className="cmp-cb-render__oldchip"
            title="This version has no built render yet — showing the frozen Figma snapshot instead."
          >no built render on this version — showing Figma</span>
        </div>
      )}

      {shotUrl ? (
        <div className="cmp-cb-render__pane">
          <ZoomPane
            platform={shownPlatform}
            label={selfLabel}
            url={shotUrl}
            viewport={viewport}
            captured
            natural={natural[shownPlatform]}
            fallbackNatural={onSelf ? detail.viewportDimensions?.[viewport] : undefined}
            onNatural={onNatural}
            onReset={resetView}
            view={view}
            setView={setView}
            hover={hover}
            setHover={setHover}
            capturing={onSelf && capturing}
            status={onSelf ? null : (active.kind === 'screen' ? 'screen frame' : 'component artwork')}
            tabs={allTabs}
            activeTabKey={active.key}
            onSelectTab={onSelectTab}
            onCloseTab={onCloseTab}
            commentMode={onSelf && commentApi.commentMode}
            onHoverInspect={onSelf ? onHoverInspect : undefined}
            onClearInspect={onSelf ? onClearInspect : undefined}
            onHoverTarget={onSelf ? onHoverTarget : undefined}
            onClearTarget={onSelf ? onClearTarget : undefined}
            onSelectTarget={onSelf ? onSelectTarget : undefined}
            {...commentProps}
          />
        </div>
      ) : !onSelf ? (
        <div className="cmp-cb-col__empty">
          {active.title} has no frozen frame on disk, so there is nothing to show in this tab.
        </div>
      ) : (
        <div className="cmp-cb-col__empty">
          {text.empty}
          {/* A null `emptyAction` means there is nothing to capture and no
              button to offer — an undesigned 2.0 state, where capturing would
              be inventing the design its OQ is waiting on. */}
          {detail.canCapture && text.emptyAction && <div style={{ marginTop: 10 }}><button className="btn btn--primary" onClick={() => onRecapture()} disabled={capturing}>{capturing ? text.busy : text.emptyAction}</button></div>}
        </div>
      )}

      {/* The timeline is the PAGE's capture log. While a borrowed tab is showing,
          picking a version would change an image that is not on screen, so it
          steps aside rather than acting invisibly. */}
      {onSelf && (
      <VersionTimeline
        versions={variant.versions ?? []}
        selectedId={versionId}
        onSelect={onSelectVersion}
        shotsVersion={shotsVersion}
        onDelete={onDeleteVersion}
      />
      )}

      {(capturing || log.length > 0) && <CaptureLogDock lines={log} capturing={capturing} viewportLabel={viewport} />}
    </div>
  );
}
