import React, { useContext, useEffect, useMemo, useRef, useState, useCallback } from 'react';
import ZoomPane from '../../components/viewer/ZoomPane.jsx';
import Thread from '../../components/viewer/Thread.jsx';
import { Link, useParams, useNavigate } from 'react-router-dom';
import { CompareContext } from './CompareContext.js';
import {
  fetchComparison,
  fetchVariant,
  fetchBuildPrompt,
  saveComparisonShared,
  saveComparisonRating,
  fetchComments,
  addComment,
  replyComment,
  resolveComment,
  deleteComment,
  startCompareCapture,
  subscribeCapture,
} from '../../api.js';

// ── Rating faces ──
const FACE_LEVELS = [
  { level: 1, label: 'Strongly dislike', mouth: 'M8 17 Q12 12 16 17', color: '#f87171' },
  { level: 2, label: 'Dislike', mouth: 'M8 16 Q12 13.5 16 16', color: '#fb923c' },
  { level: 3, label: 'Neutral', mouth: 'M8 15 L16 15', color: '#fbbf24' },
  { level: 4, label: 'Like', mouth: 'M8 14 Q12 17 16 14', color: '#a3e635' },
  { level: 5, label: 'Love it', mouth: 'M8 13.5 Q12 18 16 13.5', color: '#4ade80' },
];
function FaceIcon({ mouth }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <circle cx="12" cy="12" r="9" />
      <circle cx="9" cy="10" r="0.7" fill="currentColor" stroke="none" />
      <circle cx="15" cy="10" r="0.7" fill="currentColor" stroke="none" />
      <path d={mouth} />
    </svg>
  );
}
function RatingFaces({ value, onChange, disabled }) {
  return (
    <div className="cmp-rating" role="radiogroup" aria-label="How much do you like this implementation?">
      <span className="cmp-rating__label">Rating</span>
      {FACE_LEVELS.map((f) => {
        const active = value === f.level;
        return (
          <button key={f.level} type="button" className={`cmp-face${active ? ' cmp-face--active' : ''}`}
            style={active ? { color: f.color, borderColor: f.color } : undefined}
            title={f.label} aria-label={f.label} aria-pressed={active} disabled={disabled}
            onClick={() => onChange(active ? null : f.level)}>
            <FaceIcon mouth={f.mouth} />
          </button>
        );
      })}
    </div>
  );
}

export default function CompareDetail() {
  const { id, variant } = useParams();
  const navigate = useNavigate();
  const { shotsVersion, bumpShots, activeRun, setActiveRun, reload } = useContext(CompareContext);

  const [detail, setDetail] = useState(null);
  const [vdetail, setVdetail] = useState(null);
  const [error, setError] = useState(null);
  const [viewport, setViewport] = useState(null);
  const [tab, setTab] = useState('preview');
  const [log, setLog] = useState([]);

  const [draftJson, setDraftJson] = useState('');
  const [draftError, setDraftError] = useState(null);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);

  const [rating, setRating] = useState(null);
  const [copied, setCopied] = useState(false);
  const [promptCopied, setPromptCopied] = useState(false);
  const [promptBusy, setPromptBusy] = useState(false);
  const [captureMenuOpen, setCaptureMenuOpen] = useState(false);
  const captureMenuRef = useRef(null);
  const [commandMenuOpen, setCommandMenuOpen] = useState(false);
  const commandMenuRef = useRef(null);

  const [comments, setComments] = useState([]);
  const [commentMode, setCommentMode] = useState(false);
  const [draftPin, setDraftPin] = useState(null);
  const [selectedId, setSelectedId] = useState(null);

  // Synced zoom/pan view + mirrored cursor + per-platform natural image size
  const [view, setView] = useState({ scale: 1, cx: 0.5, cy: 0.5 });
  const [hover, setHover] = useState(null);
  const [animating, setAnimating] = useState(false);
  const animTimer = useRef(null);
  const [natural, setNatural] = useState({ iphone: null, client: null });

  // ── Live element inspection of the web iframe (precise comment targeting) ──
  const webIframeRef = useRef(null);
  const inspectReq = useRef(0);
  const inspectWaiters = useRef(new Map());
  useEffect(() => {
    const onMsg = (e) => {
      const m = e.data;
      if (!m || m.type !== 'capture-inspected') return;
      const w = inspectWaiters.current.get(m.reqId);
      if (w) { inspectWaiters.current.delete(m.reqId); w(m.target); }
    };
    window.addEventListener('message', onMsg);
    return () => window.removeEventListener('message', onMsg);
  }, []);
  // Map an image fraction → web-iframe CSS coords and ask it what's there.
  const postInspect = (fx, fy, reqId) => {
    const iframe = webIframeRef.current;
    const nat = natural.client;
    if (!iframe?.contentWindow || !nat) return false;
    iframe.contentWindow.postMessage({ type: 'capture-inspect', reqId, x: fx * nat.w, y: fy * nat.h }, '*');
    return true;
  };
  const clearInspect = () => {
    webIframeRef.current?.contentWindow?.postMessage({ type: 'capture-inspect-clear' }, '*');
  };
  const inspectWeb = (fx, fy) => new Promise((resolve) => {
    const reqId = ++inspectReq.current;
    if (!postInspect(fx, fy, reqId)) { resolve(null); return; }
    const t = setTimeout(() => { inspectWaiters.current.delete(reqId); resolve(null); }, 600);
    inspectWaiters.current.set(reqId, (target) => { clearTimeout(t); resolve(target); });
  });
  // Hover highlight (fire-and-forget; the iframe outlines the element under the
  // cursor). Throttled so a fast mousemove doesn't flood the iframe. Suspended
  // while a draft composer or a comment thread is open — the highlight stays
  // pinned to that comment's target (the cmp-target-box) instead of chasing
  // the cursor.
  const lastHoverRef = useRef(0);
  const hoverInspect = (fx, fy) => {
    if (draftPin || selectedId) return;
    const now = (typeof performance !== 'undefined' ? performance.now() : Date.now());
    if (now - lastHoverRef.current < 30) return;
    lastHoverRef.current = now;
    postInspect(fx, fy, 0);
  };
  useEffect(() => { if (!commentMode) clearInspect(); }, [commentMode]); // eslint-disable-line react-hooks/exhaustive-deps
  // Opening a draft/thread drops the last cursor outline from the iframe so
  // only the commented element stays highlighted.
  useEffect(() => { if (draftPin || selectedId) clearInspect(); }, [draftPin, selectedId]); // eslint-disable-line react-hooks/exhaustive-deps
  const resetView = useCallback(() => setView({ scale: 1, cx: 0.5, cy: 0.5 }), []);
  const cancelAnim = useCallback(() => { if (animTimer.current) clearTimeout(animTimer.current); setAnimating(false); }, []);
  const onNatural = useCallback((platform, dims) => setNatural((n) => (n[platform] && n[platform].w === dims.w && n[platform].h === dims.h ? n : { ...n, [platform]: dims })), []);

  const unsubRef = useRef(null);
  const canEdit = detail?.canCapture;
  // Live web render (iframe) for the current variant — replaces the web PNG.
  const webLive = vdetail?.webLive ?? null;
  const vpWidth = (vp) => detail?.viewportDimensions?.[vp]?.width ?? 440;
  const vpHeight = (vp) => detail?.viewportDimensions?.[vp]?.height ?? 956;
  // A `page` twin is a full-screen layout that follows the device frame (width
  // AND height), exactly like the iPhone shot — so its web box is locked to the
  // viewport dimensions. A `component` twin has intrinsic height, so its box
  // width is locked but its height comes from the live iframe's posted size.
  const isPageTwin = detail?.type === 'page';

  // Comparison-level metadata (title, group, shared/Data tab, projection).
  const refetch = async () => {
    try {
      const data = await fetchComparison(id);
      setDetail(data);
      setError(null);
      setDraftJson(JSON.stringify(data.shared ?? {}, null, 2));
      setDraftError(null);
    } catch (err) { setError(err.message); setDetail(null); }
  };
  // The variant-locked view: latest iPhone shot + live web + comments + rating.
  const loadVariant = async () => {
    if (!variant) { setVdetail(null); return; }
    try {
      const v = await fetchVariant(id, variant, viewport ?? undefined);
      setVdetail(v);
      setViewport(v.viewport);
      setRating(v.rating ?? null);
      setComments(Array.isArray(v.comments) ? v.comments : []);
    } catch { setVdetail(null); }
  };

  useEffect(() => {
    setDetail(null); setError(null); setLog([]); setSelectedId(null); setDraftPin(null);
    refetch();
    return () => unsubRef.current?.();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  useEffect(() => {
    setVdetail(null); setComments([]); setSelectedId(null); setDraftPin(null);
    loadVariant();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id, variant, shotsVersion]);

  // Reset zoom + remeasure natural when the viewport changes.
  useEffect(() => { resetView(); setNatural({ iphone: null, client: null }); }, [viewport, resetView]);

  // Seed the web iframe's natural box to the viewport width so the live
  // component lays out at the same width as the iPhone snapshot; its posted
  // height refines the box. No web twin → leave client natural null (shows the
  // "not built on web" state).
  useEffect(() => {
    if (!webLive || !viewport) return;
    const w = vpWidth(viewport);
    if (isPageTwin) {
      // Page twin: always lock to the full device frame. This must OVERWRITE any
      // earlier box — `webLive` (variant fetch) can arrive before `detail` (which
      // supplies `type`), so an approximate box may already be seeded by the time
      // isPageTwin flips true; force it back to the device dimensions here.
      const h = vpHeight(viewport);
      setNatural((n) => (n.client && n.client.w === w && n.client.h === h ? n : { ...n, client: { w, h } }));
    } else {
      // Component twin: seed an approximate box the posted capture-size refines.
      setNatural((n) => (n.client ? n : { ...n, client: { w, h: Math.round(w * 0.6) } }));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [webLive, viewport, isPageTwin]);

  // The live iframe posts its rendered height; size the web box to it — but only
  // for component twins. A page twin follows the device height (above), so its
  // intrinsic content height (a clipped 100vh layout) must not resize the box.
  useEffect(() => {
    const onMsg = (e) => {
      if (e.data?.type !== 'capture-size' || !viewport || isPageTwin) return;
      const w = vpWidth(viewport);
      const h = Math.max(1, Math.round(e.data.height));
      setNatural((n) => (n.client && n.client.h === h && n.client.w === w ? n : { ...n, client: { w, h } }));
    };
    window.addEventListener('message', onMsg);
    return () => window.removeEventListener('message', onMsg);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [viewport, isPageTwin]);

  useEffect(() => {
    const onKey = (e) => {
      const el = e.target;
      const typing = el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.isContentEditable);
      if (e.key === 'Escape') { setCommentMode(false); setDraftPin(null); setSelectedId(null); return; }
      if (typing) return;
      if ((e.key === 'c' || e.key === 'C') && tab === 'preview') { setCommentMode((m) => !m); setDraftPin(null); }
      if ((e.key === '0') && tab === 'preview') resetView();
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [tab, resetView]);

  useEffect(() => {
    if (!selectedId) return;
    const onDown = (e) => { if (!e.target.closest?.('.cmp-pop, .cmp-pin, .cmp-citem')) setSelectedId(null); };
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, [selectedId]);

  const isCapturing = activeRun?.id === id;
  const vpDims = detail?.viewportDimensions ?? {};
  // Web is a live iframe now — only the iPhone side is a screenshot.
  const shots = useMemo(() => (vdetail ? { iphone: vdetail.shots?.iphone?.url ?? null } : null), [vdetail]);
  const shotIds = { iphone: vdetail?.shots?.iphone?.screenshotId ?? null };
  const capturedFor = (platform) => (platform === 'iphone' ? !!vdetail?.shots?.iphone?.url : !!webLive);
  const numberOf = useMemo(() => {
    const m = new Map();
    [...comments].sort((a, b) => (a.createdAt < b.createdAt ? -1 : 1)).forEach((c, i) => m.set(c.id, i + 1));
    return m;
  }, [comments]);
  const unresolvedCount = comments.filter((c) => !c.resolved).length;

  const runCapture = async (platform, { allVariants = false } = {}) => {
    if (isCapturing) return;
    setCaptureMenuOpen(false);
    setLog([]);
    // Capture this variant (the runner replaces its single record — no history),
    // or "*" to capture every variant of the component in one run.
    const variantName = allVariants ? '*' : (vdetail?.variantName ?? variant);
    try {
      const { runId } = await startCompareCapture({ id, viewport, platform, variant: variantName });
      setActiveRun({ id, viewport, runId });
      unsubRef.current = subscribeCapture(runId, {
        onLine: (line) => setLog((p) => [...p, line]),
        onDone: () => { setActiveRun(null); bumpShots(); loadVariant(); },
        onError: () => setActiveRun(null),
      });
    } catch (err) { setLog((p) => [...p, `Error: ${err.message}`]); }
  };

  // Close the capture split-button menu on outside click or Escape.
  useEffect(() => {
    if (!captureMenuOpen) return;
    const onDown = (e) => { if (!captureMenuRef.current?.contains(e.target)) setCaptureMenuOpen(false); };
    const onKey = (e) => { if (e.key === 'Escape') setCaptureMenuOpen(false); };
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey);
    return () => { document.removeEventListener('mousedown', onDown); document.removeEventListener('keydown', onKey); };
  }, [captureMenuOpen]);

  // Close the Command menu on outside click or Escape.
  useEffect(() => {
    if (!commandMenuOpen) return;
    const onDown = (e) => { if (!commandMenuRef.current?.contains(e.target)) setCommandMenuOpen(false); };
    const onKey = (e) => { if (e.key === 'Escape') setCommandMenuOpen(false); };
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey);
    return () => { document.removeEventListener('mousedown', onDown); document.removeEventListener('keydown', onKey); };
  }, [commandMenuOpen]);

  const handleSave = async () => {
    let parsed;
    try { parsed = JSON.parse(draftJson); } catch (err) { setDraftError(`Invalid JSON: ${err.message}`); return; }
    setSaving(true); setDraftError(null);
    try {
      const res = await saveComparisonShared(id, parsed);
      setDetail((prev) => (prev ? { ...prev, shared: res.shared, projected: res.projected, projectionError: res.projectionError } : prev));
      setSaved(true); setTimeout(() => setSaved(false), 1800);
    } catch (err) { setDraftError(err.message); } finally { setSaving(false); }
  };

  const onRate = async (level) => {
    const prev = rating; setRating(level);
    try { await saveComparisonRating(id, level, vdetail?.versionId); reload?.(); loadVariant(); } catch { setRating(prev); }
  };

  const placeDraft = (platform, vp, x, y) => {
    setSelectedId(null);
    setDraftPin({ platform, viewport: vp, x, y, target: null });
    // Resolve which DOM element the pin lands on (hit-test the live web iframe at
    // the same fraction — works for iPhone pins too since the panes are aligned).
    inspectWeb(x, y).then((target) => {
      setDraftPin((d) => (d && d.x === x && d.y === y && d.platform === platform && d.viewport === vp ? { ...d, target } : d));
    });
  };
  const submitDraft = async (text) => {
    if (!draftPin) return;
    const t = draftPin.target;
    try {
      await addComment(id, {
        variantName: vdetail?.variantName ?? variant,
        platform: draftPin.platform, viewport: draftPin.viewport, x: draftPin.x, y: draftPin.y,
        screenshotId: shotIds[draftPin.platform] ?? undefined, text, source: 'user',
        targetSelector: t?.selector,
        targetLabel: t?.label,
        targetMeta: t ? { rect: t.rect, tag: t.tag, text: t.text, styles: t.styles } : undefined,
      });
      setDraftPin(null); setCommentMode(false); clearInspect(); await loadVariant(); reload?.();
    } catch { /* keep */ }
  };
  const addReply = async (commentId, text) => { await replyComment(id, commentId, text, 'user'); await loadVariant(); reload?.(); };
  const toggleResolve = async (c) => { await resolveComment(id, c.id, !c.resolved); await loadVariant(); reload?.(); };
  const removeComment = async (commentId) => { if (selectedId === commentId) setSelectedId(null); await deleteComment(id, commentId); await loadVariant(); reload?.(); };
  const selectFromColumn = (c) => {
    setTab('preview');
    setSelectedId(c.id);
    // Switching viewport resets to fit (whole image visible → pin visible).
    if (c.viewport !== viewport) { setViewport(c.viewport); return; }
    // Same viewport: animate-pan so the pin centers, without changing zoom.
    setAnimating(true);
    setView((v) => ({ ...v, cx: c.x, cy: c.y }));
    if (animTimer.current) clearTimeout(animTimer.current);
    animTimer.current = setTimeout(() => setAnimating(false), 360);
  };

  const copyToClipboard = async (text) => {
    try { await navigator.clipboard.writeText(text); }
    catch { const ta = document.createElement('textarea'); ta.value = text; document.body.appendChild(ta); ta.select(); try { document.execCommand('copy'); } catch {} document.body.removeChild(ta); }
  };

  // Command-menu payloads. The comparison id IS the component "struct" name
  // (e.g. CardEnrolled); kebab-case it for the Vue file path. Globs let Claude
  // resolve the exact file regardless of which Components/* subfolder it lives in.
  const kebabId = id.replace(/([a-z0-9])([A-Z])/g, '$1-$2').replace(/_/g, '-').toLowerCase();
  const resolveCommand = `/compare-resolve ${id}`;
  const iphoneTarget = `iphone/MakeReady/Components/**/${id}.swift`;
  const webTarget = `client/resources/js/components/**/${kebabId}/${kebabId}.vue`;

  const copyFromMenu = async (text) => {
    await copyToClipboard(text);
    setCommandMenuOpen(false);
    setCopied(true); setTimeout(() => setCopied(false), 1600);
  };

  // Build a full "create the web twin" prompt and copy it for the Claude CLI.
  const generateBuildPrompt = async () => {
    if (promptBusy) return;
    setPromptBusy(true);
    try {
      const { prompt } = await fetchBuildPrompt(id);
      await copyToClipboard(prompt);
      setPromptCopied(true); setTimeout(() => setPromptCopied(false), 2500);
    } catch { /* surface nothing — button stays */ } finally { setPromptBusy(false); }
  };

  if (error) {
    return <div className="empty-state"><div>{error}</div><Link to="/compare" className="btn" style={{ marginTop: 12 }}>Back to Compare</Link></div>;
  }
  if (!detail) return <div className="empty-state">Loading…</div>;

  // The column always lists every comment (resolved ones render dimmed with a
  // ✓); only the preview pins hide on resolve.
  const columnComments = [...comments].sort((a, b) => (a.createdAt < b.createdAt ? -1 : 1));
  const commentProps = {
    comments, numberOf, draft: draftPin, onPlace: placeDraft, onSubmitDraft: submitDraft, onCancelDraft: () => setDraftPin(null),
    selectedId, onSelect: setSelectedId, canEdit, onReply: addReply, onResolve: toggleResolve, onDelete: removeComment,
  };

  return (
    <div className="cmp-stage">
      {/* Fixed full-width top bar */}
      <div className="cmp-topbar">
        <div className="cmp-topbar__main">
          <div className="cmp-topbar__title">
            <div className="page-head__crumbs"><Link to="/compare">Compare</Link> / {detail.group}</div>
            <h1 className="cmp-topbar__h1">{detail.title}</h1>
          </div>
          <RatingFaces value={rating} onChange={onRate} disabled={!detail.canCapture} />
        </div>
        <div className="cmp-topbar__tools">
          <div className="cmp-vp-picker">
            <span className="cmp-vp-picker__label">Variant</span>
            <span className="cmp-version-pill">
              {vdetail?.variantName ?? '—'} · {vpDims[viewport]?.label ?? viewport ?? '—'}
            </span>
          </div>
          <button className="btn btn--mini" onClick={resetView} title="Reset zoom (0)">Fit</button>
          <div className="cmp-tab-switch">
            {['preview', 'data'].map((t) => (
              <button key={t} className={`cmp-tab-switch__btn${tab === t ? ' cmp-tab-switch__btn--active' : ''}`} onClick={() => setTab(t)}>
                {t === 'preview' ? 'Preview' : 'Data'}
              </button>
            ))}
          </div>
          {detail.canCapture && (
            <button className={`btn cmp-icon-btn${commentMode ? ' btn--primary' : ''}`}
              onClick={() => { setTab('preview'); setCommentMode((m) => !m); setDraftPin(null); }}
              title='Comment mode — click an image to drop a pin ("c")'>
              <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
              </svg>
              {commentMode ? 'Commenting…' : 'Comment'}{unresolvedCount ? <span className="cmp-count">{unresolvedCount}</span> : null}
            </button>
          )}
          <div className="cmp-capsplit" ref={commandMenuRef}>
            <button
              className="btn cmp-icon-btn"
              onClick={() => setCommandMenuOpen((o) => !o)}
              aria-haspopup="menu"
              aria-expanded={commandMenuOpen}
              title="Copy a command or component reference"
            >
              <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                <polyline points="4 17 10 11 4 5" /><line x1="12" y1="19" x2="20" y2="19" />
              </svg>
              {copied ? 'Copied!' : 'Command'}
              <svg className={`cmp-btn-caret${commandMenuOpen ? ' cmp-btn-caret--open' : ''}`} viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                <polyline points="6 9 12 15 18 9" />
              </svg>
            </button>
            {commandMenuOpen && (
              <div className="cmp-capsplit__menu cmp-capsplit__menu--paths" role="menu">
                <button className="cmp-capsplit__item" role="menuitem" onClick={() => copyFromMenu(resolveCommand)}>
                  <span className="cmp-capsplit__item-name">Resolve comments</span>
                  <span className="cmp-capsplit__item-sub">{resolveCommand}</span>
                </button>
                <button className="cmp-capsplit__item" role="menuitem" onClick={() => copyFromMenu(iphoneTarget)}>
                  <span className="cmp-capsplit__item-name">iPhone target</span>
                  <span className="cmp-capsplit__item-sub">{iphoneTarget}</span>
                </button>
                <button className="cmp-capsplit__item" role="menuitem" onClick={() => copyFromMenu(webTarget)}>
                  <span className="cmp-capsplit__item-name">web target</span>
                  <span className="cmp-capsplit__item-sub">{webTarget}</span>
                </button>
              </div>
            )}
          </div>
          {detail.canCapture && (
            <div className="cmp-capture-group">
              {/* Web is rendered live (iframe) — only the iPhone native snapshot is
                  captured. Split button: main = this variant, caret = pick scope. */}
              <div className="cmp-capsplit" ref={captureMenuRef}>
                <button
                  className="btn btn--primary cmp-capsplit__main"
                  onClick={() => runCapture('iphone')}
                  disabled={isCapturing}
                >
                  {isCapturing ? 'Capturing…' : 'Capture iPhone'}
                </button>
                <button
                  className="btn btn--primary cmp-capsplit__caret"
                  onClick={() => setCaptureMenuOpen((o) => !o)}
                  disabled={isCapturing}
                  aria-haspopup="menu"
                  aria-expanded={captureMenuOpen}
                  title="Capture options"
                >
                  <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                    <polyline points="6 9 12 15 18 9" />
                  </svg>
                </button>
                {captureMenuOpen && (
                  <div className="cmp-capsplit__menu" role="menu">
                    <button className="cmp-capsplit__item" role="menuitem" onClick={() => runCapture('iphone')}>
                      <span className="cmp-capsplit__item-name">{vdetail?.variantName ?? variant}</span>
                      <span className="cmp-capsplit__item-sub">this variant</span>
                    </button>
                    <button className="cmp-capsplit__item" role="menuitem" onClick={() => runCapture('iphone', { allVariants: true })}>
                      <span className="cmp-capsplit__item-name">All variants</span>
                      <span className="cmp-capsplit__item-sub">{detail.variantCount ? `${detail.variantCount} total` : 'whole component'}</span>
                    </button>
                  </div>
                )}
              </div>
            </div>
          )}
        </div>
      </div>

      {detail.projectionError && <div className="error-banner" style={{ margin: 0 }}>Adapter error: {detail.projectionError}</div>}

      {tab === 'preview' ? (
        <div className="cmp-3col">
          <ZoomPane platform="iphone" label="iPhone" url={shots?.iphone ? `${shots.iphone}?v=${shotsVersion}` : null}
            missingLabel="not captured"
            viewport={viewport} captured={capturedFor('iphone')} natural={natural.iphone} fallbackNatural={vpDims[viewport]} onNatural={onNatural} onReset={resetView}
            view={view} setView={setView} hover={hover} setHover={setHover} capturing={isCapturing}
            animating={animating} clearAnim={cancelAnim}
            onHoverInspect={hoverInspect} onClearInspect={clearInspect}
            commentMode={commentMode} {...commentProps} />
          {/* Web is a live iframe — it's never captured, so capturing={false} keeps it from dimming/spinning during an iPhone capture. */}
          <ZoomPane platform="client" label="Web" webUrl={webLive?.url ?? null}
            missingLabel="not built on web yet"
            missingAction={!webLive ? (
              <button className="btn btn--primary cmp-genprompt" onClick={generateBuildPrompt} disabled={promptBusy}>
                {promptCopied ? 'Copied to clipboard ✓' : promptBusy ? 'Generating…' : 'Generate prompt'}
              </button>
            ) : null}
            viewport={viewport} captured={!!webLive} natural={natural.client} fallbackNatural={vpDims[viewport]} onNatural={onNatural} onReset={resetView}
            view={view} setView={setView} hover={hover} setHover={setHover} capturing={false}
            animating={animating} clearAnim={cancelAnim}
            iframeRef={webIframeRef} onHoverInspect={hoverInspect} onClearInspect={clearInspect}
            commentMode={commentMode} {...commentProps} />

          <aside className="cmp-comments">
            <div className="cmp-comments__head">
              <span className="cmp-comments__title">Comments</span>
              {unresolvedCount > 0 && <span className="cmp-comments__open">{unresolvedCount} open</span>}
            </div>
            {commentMode && <div className="cmp-comments__hint">Click on either image to drop a pin · Esc to exit</div>}
            <div className="cmp-comments__list">
              {columnComments.length === 0 && (
                <div className="cmp-comments__empty">No comments yet.{detail.canCapture ? <> Press <kbd>c</kbd> or hit <strong>Comment</strong>, then click a spot on either image.</> : null}</div>
              )}
              {columnComments.map((c) => {
                const selected = c.id === selectedId;
                return (
                  <div key={c.id} className={`cmp-citem${selected ? ' cmp-citem--selected' : ''}${c.resolved ? ' cmp-citem--resolved' : ''}`}
                    role="button" tabIndex={0} onClick={() => selectFromColumn(c)}
                    onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); selectFromColumn(c); } }}>
                    <div className="cmp-citem__head">
                      <span className="cmp-citem__num">{c.resolved ? '✓' : numberOf.get(c.id)}</span>
                      <span className={`cmp-citem__plat cmp-citem__plat--${c.platform}`}>{c.platform === 'iphone' ? 'iPhone' : 'Web'}</span>
                      <span className="cmp-citem__vp">{c.viewport}</span>
                      {c.targetLabel && <span className="cmp-target-chip cmp-target-chip--sm" title={c.targetSelector}>◎ {c.targetLabel}</span>}
                    </div>
                    <div className="cmp-citem__thread"><Thread comment={c} canEdit={false} /></div>
                  </div>
                );
              })}
            </div>
          </aside>
        </div>
      ) : (
        <div className="cmp-data cmp-data--full">
          <div className="cmp-data__shared">
            <div className="cmp-data__head">
              <span className="cmp-data__title">Shared data</span>
              <span className="cmp-data__hint">Edited here, projected into both platforms below.</span>
              {detail.canCapture && (
                <div className="cmp-data__actions">
                  {saved && <span className="cmp-data__saved">saved ✓</span>}
                  <button className="btn btn--primary btn--mini" onClick={handleSave} disabled={saving}>{saving ? 'Saving…' : 'Save'}</button>
                </div>
              )}
            </div>
            {draftError && <div className="error-banner">{draftError}</div>}
            <textarea className="cmp-data__editor" value={draftJson} onChange={(e) => setDraftJson(e.target.value)} spellCheck={false} readOnly={!detail.canCapture} />
          </div>
          <div className="cmp-data__projections">
            <div className="cmp-data__proj"><div className="cmp-data__proj-title">iPhone fixture (state / auth)</div><pre className="fixture-panel__pre">{JSON.stringify(detail.projected?.iphone ?? {}, null, 2)}</pre></div>
            <div className="cmp-data__proj"><div className="cmp-data__proj-title">Web fixture (data)</div><pre className="fixture-panel__pre">{JSON.stringify(detail.projected?.client ?? {}, null, 2)}</pre></div>
          </div>
        </div>
      )}

      {(isCapturing || log.length > 0) && (
        <div className="cmp-log cmp-log--docked">
          <div className="cmp-log__head">{isCapturing ? <><span className="layout__activity-spinner" /> Capturing {activeRun.viewport}…</> : 'Last capture log'}</div>
          <pre className="cmp-log__body">{log.join('\n') || '…'}</pre>
        </div>
      )}
    </div>
  );
}
