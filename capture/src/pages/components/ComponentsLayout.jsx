// The iPhone component browser — 4-column shell (component-browser 07 §2/§3).
// Route: /components/* (React Router v6 splat, G2). The splat parses as
// <component-path>[/<variant>]: the longest prefix resolving to a component in
// the fs tree is the path; a trailing extra segment is the variant.
//
// This host owns (like CompareDetail does for /compare): the version-locked
// payload (render + comments), comment mode/draft/selection, the capture run,
// and the keybindings — the viewer components stay controlled (CR6).
import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { NavLink, useNavigate, useParams } from 'react-router-dom';
import { io } from 'socket.io-client';
import {
  fetchComponentsTree,
  fetchComponentDetail,
  fetchComponentVersion,
  saveComponentFixture,
  addComment,
  replyComment,
  resolveComment,
  deleteComment,
  startCompareCapture,
  subscribeCapture,
} from '../../api.js';
import ComponentTree from './ComponentTree.jsx';
import VariantList from './VariantList.jsx';
import RenderPane from './RenderPane.jsx';
import SidePanel from './SidePanel.jsx';

function indexTree(tree) {
  const byPath = new Map();
  const visit = (nodes) => {
    for (const n of nodes) {
      byPath.set(n.path, n);
      if (n.type === 'folder') visit(n.children);
    }
  };
  visit(tree ?? []);
  return byPath;
}

function parseSplat(splat, byPath) {
  if (!splat) return { path: null, variant: null };
  const segs = splat.split('/').filter(Boolean).map(decodeURIComponent);
  const full = segs.join('/');
  if (byPath.get(full)?.type === 'component') return { path: full, variant: null };
  if (segs.length > 1) {
    const prefix = segs.slice(0, -1).join('/');
    if (byPath.get(prefix)?.type === 'component') return { path: prefix, variant: segs[segs.length - 1] };
  }
  return { path: full || null, variant: null };
}

export default function ComponentsLayout() {
  const navigate = useNavigate();
  const splat = useParams()['*'] ?? '';

  const [treeData, setTreeData] = useState(null);
  const [treeError, setTreeError] = useState(null);
  const [detail, setDetail] = useState(null);
  const [detailError, setDetailError] = useState(null);
  const [viewport, setViewport] = useState(null);
  const [versionId, setVersionId] = useState(null); // null = current
  const [vdata, setVdata] = useState(null); // version-locked payload (render + comments)
  const [liveConnected, setLiveConnected] = useState(false);
  const [shotsVersion, setShotsVersion] = useState(() => Date.now());

  // Comment state (host-owned, CR6)
  const [commentMode, setCommentMode] = useState(false);
  const [draftPin, setDraftPin] = useState(null);
  const [selectedCommentId, setSelectedCommentId] = useState(null);

  // Capture run
  const [log, setLog] = useState([]);
  const [capturing, setCapturing] = useState(false);
  const unsubRef = useRef(null);

  const byPath = useMemo(() => indexTree(treeData?.tree), [treeData]);
  const { path, variant } = useMemo(() => parseSplat(splat, byPath), [splat, byPath]);

  const loadTree = useCallback(async () => {
    try { setTreeData(await fetchComponentsTree()); setTreeError(null); }
    catch (err) { setTreeError(err.message); }
  }, []);
  useEffect(() => { loadTree(); }, [loadTree]);

  const loadDetail = useCallback(async () => {
    if (!path || !byPath.size) { setDetail(null); return; }
    const node = byPath.get(path);
    if (!node || node.type !== 'component') { setDetail(null); setDetailError(node ? null : `Unknown component "${path}"`); return; }
    try {
      const d = await fetchComponentDetail(path, viewport ?? undefined);
      setDetail(d);
      setDetailError(null);
      if (!viewport) setViewport(d.viewport);
    } catch (err) { setDetail(null); setDetailError(err.message); }
  }, [path, byPath, viewport]);
  useEffect(() => { loadDetail(); }, [loadDetail, shotsVersion]);

  // Selecting a component lands on its first variant (replace, like /compare).
  useEffect(() => {
    if (path && !variant && detail?.path === path && detail.variants?.length) {
      navigate(`/components/${path}/${encodeURIComponent(detail.variants[0].name)}`, { replace: true });
    }
  }, [path, variant, detail, navigate]);

  const activeVariant = useMemo(() => {
    if (!detail?.variants?.length) return null;
    return detail.variants.find((v) => v.name === variant) ?? detail.variants[0];
  }, [detail, variant]);

  // Reset version + comment state when the target changes.
  useEffect(() => { setVersionId(null); setSelectedCommentId(null); setDraftPin(null); setCommentMode(false); }, [path, variant, viewport]);

  // The version-locked payload: selected old version, or the current one.
  const activeVersionId = versionId ?? activeVariant?.versions?.[0]?.versionId ?? null;
  const loadVdata = useCallback(async () => {
    if (!activeVersionId) { setVdata(null); return; }
    try { setVdata(await fetchComponentVersion(activeVersionId)); }
    catch { setVdata(null); }
  }, [activeVersionId]);
  useEffect(() => { loadVdata(); }, [loadVdata, shotsVersion]);

  // Live updates: any finished capture refreshes the detail + tree badges.
  const bumpShots = useCallback(() => { setShotsVersion(Date.now()); loadTree(); }, [loadTree]);
  useEffect(() => {
    const socket = io({ path: '/socket.io', transports: ['websocket', 'polling'] });
    let timer = null;
    const refresh = () => { clearTimeout(timer); timer = setTimeout(() => bumpShots(), 300); };
    socket.on('connect', () => { setLiveConnected(true); refresh(); });
    socket.on('disconnect', () => setLiveConnected(false));
    socket.on('compare:shot', refresh);
    socket.on('compare:done', refresh);
    return () => { clearTimeout(timer); socket.close(); };
  }, [bumpShots]);

  // ── Element hit-testing (ported from CompareDetail): a HIDDEN live web-twin
  // iframe is the hit-test oracle — hovering in comment mode outlines the
  // element under the cursor on the shot, and a placed pin records
  // targetSelector/targetLabel/targetMeta. No Vue twin → quietly disabled.
  const webIframeRef = useRef(null);
  const inspectWaiters = useRef(new Map());
  const inspectReq = useRef(0);
  const lastHoverRef = useRef(0);
  const [webNat, setWebNat] = useState(null); // hidden iframe CSS box {w,h}
  const [hoverTarget, setHoverTarget] = useState(null);
  const webLive = vdata?.webLive ?? null;

  useEffect(() => {
    const onMsg = (e) => {
      const m = e.data;
      if (!m || typeof m !== 'object') return;
      if (m.type === 'capture-inspected') {
        const w = inspectWaiters.current.get(m.reqId);
        if (w) { inspectWaiters.current.delete(m.reqId); w(m.target); }
      } else if (m.type === 'capture-size') {
        // The live harness posts its rendered height; keep the hidden iframe's
        // box at the device width so fractions line up with the iPhone shot.
        const width = detail?.viewportDimensions?.[viewport]?.width ?? 440;
        const h = Math.max(1, Math.round(m.height));
        setWebNat((n) => (n && n.w === width && n.h === h ? n : { w: width, h }));
      }
    };
    window.addEventListener('message', onMsg);
    return () => window.removeEventListener('message', onMsg);
  }, [detail, viewport]);

  // Seed the box at the device width; capture-size refines the height.
  useEffect(() => {
    if (!webLive) { setWebNat(null); return; }
    const w = detail?.viewportDimensions?.[viewport]?.width ?? 440;
    setWebNat((n) => (n ?? { w, h: Math.round(w * 0.6) }));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [webLive?.url, viewport]);

  const postInspect = (fx, fy, reqId) => {
    const iframe = webIframeRef.current;
    if (!iframe?.contentWindow || !webNat) return false;
    iframe.contentWindow.postMessage({ type: 'capture-inspect', reqId, x: fx * webNat.w, y: fy * webNat.h }, '*');
    return true;
  };
  const inspectWeb = (fx, fy) => new Promise((resolve) => {
    const reqId = ++inspectReq.current;
    if (!postInspect(fx, fy, reqId)) { resolve(null); return; }
    const t = setTimeout(() => { inspectWaiters.current.delete(reqId); resolve(null); }, 600);
    inspectWaiters.current.set(reqId, (target) => { clearTimeout(t); resolve(target); });
  });
  const clearInspect = useCallback(() => {
    webIframeRef.current?.contentWindow?.postMessage({ type: 'capture-inspect-clear' }, '*');
    setHoverTarget(null);
  }, []);
  // Hover highlight (throttled). Suspended while a draft composer or a thread
  // is open — the target box stays pinned to that comment's element instead.
  const hoverInspect = (fx, fy) => {
    if (draftPin || selectedCommentId) return;
    const now = (typeof performance !== 'undefined' ? performance.now() : Date.now());
    if (now - lastHoverRef.current < 40) return;
    lastHoverRef.current = now;
    inspectWeb(fx, fy).then((target) => setHoverTarget(target));
  };
  useEffect(() => { if (!commentMode || draftPin || selectedCommentId) clearInspect(); }, [commentMode, draftPin, selectedCommentId, clearInspect]);

  // ── Comments (anchored to the VIEWED version's screenshot — DB-2) ──
  const canComment = !!detail?.canCapture && !!vdata?.shot;
  const refreshComments = useCallback(async () => { await loadVdata(); await loadDetail(); loadTree(); }, [loadVdata, loadDetail, loadTree]);

  const placeDraft = (platform, vp, x, y) => {
    setSelectedCommentId(null);
    const hasLive = !!(webLive && webIframeRef.current);
    // target: null = "resolving…"; resolved to undefined when nothing was hit
    // (or there's no twin) so the draft chip disappears instead of sticking.
    setDraftPin({ platform, viewport: vp, x, y, ...(hasLive ? { target: null } : {}) });
    if (!hasLive) return;
    inspectWeb(x, y).then((target) => {
      setDraftPin((d) => (d && d.x === x && d.y === y && d.platform === platform && d.viewport === vp ? { ...d, target: target ?? undefined } : d));
    });
  };
  const submitDraft = async (text) => {
    if (!draftPin || !detail?.comparisonId) return;
    try {
      await addComment(detail.comparisonId, {
        variantName: vdata?.variantName ?? activeVariant?.name ?? 'default',
        platform: 'iphone',
        viewport: draftPin.viewport,
        x: draftPin.x,
        y: draftPin.y,
        screenshotId: vdata?.screenshotId ?? undefined,
        text,
        source: 'user',
        targetSelector: draftPin.target?.selector,
        targetLabel: draftPin.target?.label,
        targetMeta: draftPin.target
          ? { rect: draftPin.target.rect, tag: draftPin.target.tag, text: draftPin.target.text, styles: draftPin.target.styles }
          : undefined,
      });
      setDraftPin(null); setCommentMode(false); clearInspect();
      await refreshComments();
    } catch { /* keep the draft so the text isn't lost */ }
  };
  const onReply = async (commentId, text) => { await replyComment(detail.comparisonId, commentId, text, 'user'); await refreshComments(); };
  const onResolve = async (c) => { await resolveComment(detail.comparisonId, c.id, !c.resolved); await refreshComments(); };
  const onDelete = async (commentId) => {
    if (selectedCommentId === commentId) setSelectedCommentId(null);
    await deleteComment(detail.comparisonId, commentId);
    await refreshComments();
  };

  // ── Recapture (always platform:"iphone" — CR10) ──
  const runCapture = async ({ allVariants = false } = {}) => {
    if (capturing || !detail?.comparisonId || !activeVariant) return;
    setLog([]); setCapturing(true);
    try {
      // This variant, or "*" to recapture every variant of the component.
      const { runId } = await startCompareCapture({ id: detail.comparisonId, viewport, platform: 'iphone', variant: allVariants ? '*' : activeVariant.name });
      unsubRef.current = subscribeCapture(runId, {
        onLine: (line) => setLog((p) => [...p, line]),
        onDone: () => { setCapturing(false); bumpShots(); },
        onError: () => setCapturing(false),
      });
    } catch (err) {
      setCapturing(false);
      setLog((p) => [...p, `Error: ${err.message}`]);
    }
  };
  useEffect(() => () => unsubRef.current?.(), []);

  // ── Data editor save (D8) ──
  const saveFixture = async (shared, { recapture = false } = {}) => {
    await saveComponentFixture(detail.path, activeVariant?.name ?? 'default', shared);
    await loadDetail();
    if (recapture) await runCapture();
  };

  // ── Keybindings (host-owned, CR6): c = comment mode, Esc = cancel ──
  useEffect(() => {
    const onKey = (e) => {
      const el = e.target;
      const typing = el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.isContentEditable);
      if (e.key === 'Escape') { setCommentMode(false); setDraftPin(null); setSelectedCommentId(null); return; }
      if (typing) return;
      if ((e.key === 'c' || e.key === 'C') && canComment) { setCommentMode((m) => !m); setDraftPin(null); }
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [canComment]);

  const selectComponent = (node) => navigate(`/components/${node.path}`);
  const selectVariant = (name) => navigate(`/components/${path}/${encodeURIComponent(name)}`);

  const commentApi = {
    comments: vdata?.comments ?? [],
    commentMode, setCommentMode,
    draftPin, placeDraft, submitDraft, cancelDraft: () => setDraftPin(null),
    selectedCommentId, setSelectedCommentId,
    canComment, onReply, onResolve, onDelete,
  };

  return (
    <div className="layout cmp-cb">
      <header className="layout__header">
        <div className="layout__brand"><span className="layout__brand-dot" /><NavLink to="/">MakeReady Capture</NavLink></div>
        <div className="layout__platform-tabs">
          <NavLink to="/client" className="layout__platform-tab">Web</NavLink>
          <NavLink to="/iphone" className="layout__platform-tab">iPhone</NavLink>
          <NavLink to="/compare" className="layout__platform-tab">Compare</NavLink>
          <NavLink to="/components" className="layout__platform-tab layout__platform-tab--active">Components</NavLink>
        </div>
        <span
          title={liveConnected ? 'Live — the view auto-updates when captures complete' : 'Live updates offline'}
          style={{ marginLeft: 'auto', display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11, letterSpacing: 0.3, textTransform: 'uppercase', color: liveConnected ? '#4ade80' : '#6b7280' }}
        >
          <span style={{ width: 7, height: 7, borderRadius: '50%', background: liveConnected ? '#4ade80' : '#6b7280', boxShadow: liveConnected ? '0 0 6px #4ade80' : 'none' }} />
          Live
        </span>
      </header>

      <div className="cmp-cb__cols">
        {treeError
          ? <div className="cmp-cb-col cmp-cb-col--tree"><div className="error-banner">{treeError}<button className="btn btn--mini" style={{ marginLeft: 8 }} onClick={loadTree}>Retry</button></div></div>
          : <ComponentTree tree={treeData?.tree ?? null} selectedPath={path} onSelect={selectComponent} />}

        <VariantList detail={detail} selectedVariant={activeVariant?.name} onSelect={selectVariant} />

        <RenderPane
          detail={detail}
          detailError={detailError}
          variant={activeVariant}
          viewport={viewport}
          onViewport={setViewport}
          versionId={versionId}
          onSelectVersion={setVersionId}
          vdata={vdata}
          shotsVersion={shotsVersion}
          capturing={capturing}
          log={log}
          onRecapture={runCapture}
          commentApi={commentApi}
          onHoverInspect={hoverInspect}
          onClearInspect={clearInspect}
          hoverBox={hoverTarget?.rect ?? null}
        />

        <SidePanel
          detail={detail}
          variant={activeVariant}
          activeVersionId={activeVersionId}
          currentVersionId={activeVariant?.versions?.[0]?.versionId ?? null}
          onSelectVersion={setVersionId}
          commentApi={commentApi}
          onSaveFixture={saveFixture}
        />
      </div>

      {/* Hidden live web twin — hit-test oracle for element-targeted comments. */}
      {webLive?.url && (
        <iframe
          ref={webIframeRef}
          src={webLive.url}
          title="web twin hit-test"
          aria-hidden="true"
          tabIndex={-1}
          style={{ position: 'fixed', left: -10000, top: 0, width: webNat?.w ?? 440, height: webNat?.h ?? 600, border: 0, pointerEvents: 'none' }}
        />
      )}
    </div>
  );
}
