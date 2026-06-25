import React, { useContext, useEffect, useMemo, useRef, useState, useCallback } from 'react';
import { Link, useParams, useNavigate } from 'react-router-dom';
import { CompareContext } from './CompareContext.js';
import {
  fetchComparison,
  fetchVersion,
  fetchVersions,
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

const MIN_SCALE = 0.2;
const MAX_SCALE = 8;
const clamp = (n, lo, hi) => Math.max(lo, Math.min(hi, n));

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

function formatTime(iso) {
  try { return new Date(iso).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }); }
  catch { return iso; }
}
function SourceTag({ source }) {
  return <span className={`cmp-msg__src cmp-msg__src--${source}`}>{source === 'claude' ? 'Claude' : 'You'}</span>;
}

function Thread({ comment, canEdit, autoFocusReply, onReply, onResolve, onDelete }) {
  const [reply, setReply] = useState('');
  const [busy, setBusy] = useState(false);
  const replyRef = useRef(null);
  useEffect(() => { if (autoFocusReply && canEdit) replyRef.current?.focus({ preventScroll: true }); }, [autoFocusReply, canEdit]);
  const submit = async () => {
    if (!reply.trim()) return;
    setBusy(true);
    try { await onReply(comment.id, reply.trim()); setReply(''); } finally { setBusy(false); }
  };
  return (
    <>
      <div className="cmp-thread__msgs">
        {(comment.messages ?? []).map((m) => (
          <div className="cmp-msg" key={m.id}>
            <div className="cmp-msg__meta"><SourceTag source={m.source} /><span className="cmp-msg__time">{formatTime(m.createdAt)}</span></div>
            <div className="cmp-msg__text">{m.text}</div>
          </div>
        ))}
      </div>
      {canEdit && (
        <div className="cmp-thread__reply">
          <textarea ref={replyRef} className="cmp-thread__input" placeholder="Reply…" value={reply}
            onChange={(e) => setReply(e.target.value)}
            onKeyDown={(e) => { if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') submit(); }} />
          <div className="cmp-thread__actions">
            <button className={`btn btn--mini cmp-resolve${comment.resolved ? ' cmp-resolve--done' : ''}`}
              onClick={() => onResolve(comment)} title={comment.resolved ? 'Reopen' : 'Mark resolved'}>
              <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                <path d="M14 9V5a3 3 0 0 0-3-3l-4 9v11h11.28a2 2 0 0 0 2-1.7l1.38-9a2 2 0 0 0-2-2.3z" />
                <path d="M7 22H4a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2h3" />
              </svg>
              {comment.resolved ? 'Resolved' : 'Resolve'}
            </button>
            <button className="btn btn--mini cmp-resolve" onClick={submit} disabled={busy || !reply.trim()}>Reply</button>
            <button className="cmp-thread__del" title="Delete comment" aria-label="Delete comment"
              onClick={() => { if (window.confirm('Delete this comment?')) onDelete(comment.id); }}>
              <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                <polyline points="3 6 5 6 21 6" /><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6" /><path d="M10 11v6M14 11v6" /><path d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2" />
              </svg>
            </button>
          </div>
        </div>
      )}
    </>
  );
}

// Pins + draft composer + open thread, living INSIDE the zoom/pan canvas so they
// track the image. `inv` (1/scale) counter-scales pins so they stay constant size.
function CommentLayer({
  platform, viewport, comments, numberOf, commentMode, draft, inv,
  onPlace, onSubmitDraft, onCancelDraft, selectedId, onSelect,
  canEdit, onReply, onResolve, onDelete,
}) {
  const [draftVal, setDraftVal] = useState('');
  useEffect(() => { setDraftVal(''); }, [draft?.x, draft?.y, draft?.platform]);

  const handleClick = (e) => {
    if (!commentMode) return;
    const rect = e.currentTarget.getBoundingClientRect();
    onPlace(platform, viewport, (e.clientX - rect.left) / rect.width, (e.clientY - rect.top) / rect.height);
  };
  const here = comments.filter((c) => c.platform === platform && c.viewport === viewport);
  const showDraft = draft && draft.platform === platform && draft.viewport === viewport;

  return (
    <div className={`cmp-commentlayer${commentMode ? ' cmp-commentlayer--placing' : ''}`} onClick={handleClick}>
      {here.map((c) => {
        const side = c.x > 0.55 ? 'left' : 'right';
        const selected = c.id === selectedId;
        return (
          <div className="cmp-pin" key={c.id} style={{ left: `${c.x * 100}%`, top: `${c.y * 100}%`, transform: `scale(${inv})`, transformOrigin: '0 0' }}>
            <button className={`cmp-pin__dot${c.resolved ? ' cmp-pin__dot--resolved' : ''}${selected ? ' cmp-pin__dot--selected' : ''}`}
              onClick={(e) => { e.stopPropagation(); onSelect(selected ? null : c.id); }}
              onMouseDown={(e) => e.stopPropagation()}
              title={c.messages?.[0]?.text ?? 'Comment'}>
              {c.resolved ? '✓' : numberOf.get(c.id)}
            </button>
            {selected && (
              <div className={`cmp-pop cmp-pop--${side}`} onClick={(e) => e.stopPropagation()} onMouseDown={(e) => e.stopPropagation()}>
                <div className="cmp-pop__head">
                  <span className="cmp-pop__title">Comment {numberOf.get(c.id)}</span>
                  <button className="cmp-pop__close" onClick={() => onSelect(null)} title="Close" aria-label="Close">
                    <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" aria-hidden="true">
                      <line x1="6" y1="6" x2="18" y2="18" /><line x1="18" y1="6" x2="6" y2="18" />
                    </svg>
                  </button>
                </div>
                <Thread comment={c} canEdit={canEdit} autoFocusReply onReply={onReply} onResolve={onResolve} onDelete={onDelete} />
              </div>
            )}
          </div>
        );
      })}
      {showDraft && (
        <div className="cmp-pin" style={{ left: `${draft.x * 100}%`, top: `${draft.y * 100}%`, transform: `scale(${inv})`, transformOrigin: '0 0' }}>
          <span className="cmp-pin__dot cmp-pin__dot--draft">•</span>
          <div className={`cmp-pop cmp-pop--${draft.x > 0.55 ? 'left' : 'right'}`} onClick={(e) => e.stopPropagation()} onMouseDown={(e) => e.stopPropagation()}>
            <textarea className="cmp-thread__input" autoFocus placeholder="Add a comment…" value={draftVal}
              onChange={(e) => setDraftVal(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Escape') onCancelDraft(); if ((e.metaKey || e.ctrlKey) && e.key === 'Enter' && draftVal.trim()) onSubmitDraft(draftVal.trim()); }} />
            <div className="cmp-thread__actions">
              <button className="btn btn--primary btn--mini" disabled={!draftVal.trim()} onClick={() => onSubmitDraft(draftVal.trim())}>Submit</button>
              <button className="btn btn--mini" onClick={onCancelDraft}>Cancel</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function useElementSize() {
  const ref = useRef(null);
  const [size, setSize] = useState({ w: 0, h: 0 });
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const ro = new ResizeObserver((entries) => {
      const cr = entries[0].contentRect;
      setSize({ w: cr.width, h: cr.height });
    });
    ro.observe(el);
    setSize({ w: el.clientWidth, h: el.clientHeight });
    return () => ro.disconnect();
  }, []);
  return [ref, size];
}

// One image pane: shares {scale,cx,cy} with its sibling and computes its own
// fit. Emits hover as an image fraction; draws a ghost for the sibling's hover.
function ZoomPane({
  platform, label, url, viewport, captured, natural, fallbackNatural, onNatural, onReset,
  view, setView, hover, setHover, capturing, animating, clearAnim,
  commentMode, ...commentProps
}) {
  const [vpRef, size] = useElementSize();
  const drag = useRef(null);

  const geom = useMemo(() => {
    const { w: W, h: H } = size;
    const nw = natural?.w || fallbackNatural?.width || 1;
    const nh = natural?.h || fallbackNatural?.height || 2;
    if (!W || !H) return null;
    const fit = Math.min(W / nw, H / nh);
    const baseW = nw * fit;
    const baseH = nh * fit;
    const tx = W / 2 - view.cx * baseW * view.scale;
    const ty = H / 2 - view.cy * baseH * view.scale;
    return { W, H, baseW, baseH, tx, ty };
  }, [size, natural, fallbackNatural, view]);

  // Wheel zoom-to-cursor (native, non-passive)
  useEffect(() => {
    const el = vpRef.current;
    if (!el) return;
    const onWheel = (e) => {
      e.preventDefault();
      if (!geom) return;
      clearAnim?.();
      const rect = el.getBoundingClientRect();
      const mx = e.clientX - rect.left;
      const my = e.clientY - rect.top;
      const factor = e.deltaY > 0 ? 0.94 : 1 / 0.94;
      const { baseW, baseH, tx, ty, W, H } = geom;
      const fx = (mx - tx) / (baseW * view.scale);
      const fy = (my - ty) / (baseH * view.scale);
      const newScale = clamp(view.scale * factor, MIN_SCALE, MAX_SCALE);
      setView({
        scale: newScale,
        cx: (W / 2 - mx) / (baseW * newScale) + fx,
        cy: (H / 2 - my) / (baseH * newScale) + fy,
      });
    };
    el.addEventListener('wheel', onWheel, { passive: false });
    return () => el.removeEventListener('wheel', onWheel);
  }, [geom, view.scale, setView, vpRef]);

  const onMouseDown = (e) => {
    if (commentMode) return; // placement handled by the comment layer
    if (e.target.closest('.cmp-pin, .cmp-pop')) return;
    if (e.button !== 0) return;
    clearAnim?.();
    drag.current = { x: e.clientX, y: e.clientY };
    const move = (ev) => {
      if (!drag.current || !geom) return;
      const dx = ev.clientX - drag.current.x;
      const dy = ev.clientY - drag.current.y;
      drag.current = { x: ev.clientX, y: ev.clientY };
      setView((v) => ({ ...v, cx: v.cx - dx / (geom.baseW * v.scale), cy: v.cy - dy / (geom.baseH * v.scale) }));
    };
    const up = () => { drag.current = null; window.removeEventListener('mousemove', move); window.removeEventListener('mouseup', up); };
    window.addEventListener('mousemove', move);
    window.addEventListener('mouseup', up);
  };

  const onMouseMove = (e) => {
    if (!geom) return;
    const rect = e.currentTarget.getBoundingClientRect();
    const { baseW, baseH, tx, ty } = geom;
    const fx = (e.clientX - rect.left - tx) / (baseW * view.scale);
    const fy = (e.clientY - rect.top - ty) / (baseH * view.scale);
    setHover({ fx, fy, source: platform });
  };

  // Ghost cursor mirrored from the opposite pane.
  let ghost = null;
  if (hover && hover.source !== platform && geom) {
    const gx = geom.tx + hover.fx * geom.baseW * view.scale;
    const gy = geom.ty + hover.fy * geom.baseH * view.scale;
    if (gx >= 0 && gx <= geom.W && gy >= 0 && gy <= geom.H) ghost = { gx, gy };
  }

  const zoomPct = Math.round(view.scale * 100);

  return (
    <div className="cmp-zpane">
      <div className="cmp-zpane__head">
        <span className="cmp-pane__title">{label}</span>
        <span className={`cmp-pane__status ${captured ? 'is-ok' : 'is-missing'}`}>{captured ? 'captured' : 'not captured'}</span>
        <span className="cmp-zpane__zoom">{zoomPct}%</span>
        <button className="cmp-zpane__reset" onClick={onReset} title="Fit & center (0)" aria-label="Fit and center">
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M8 3H5a2 2 0 0 0-2 2v3" /><path d="M21 8V5a2 2 0 0 0-2-2h-3" />
            <path d="M3 16v3a2 2 0 0 0 2 2h3" /><path d="M16 21h3a2 2 0 0 0 2-2v-3" />
          </svg>
        </button>
      </div>
      <div
        ref={vpRef}
        className={`cmp-zpane__viewport${commentMode ? '' : ' cmp-zpane__viewport--grab'}`}
        onMouseDown={onMouseDown}
        onMouseMove={onMouseMove}
        onMouseLeave={() => setHover((h) => (h && h.source === platform ? null : h))}
      >
        {url && geom ? (
          <div
            className={`cmp-zpane__canvas${animating ? ' cmp-zpane__canvas--anim' : ''}`}
            style={{ width: geom.baseW, height: geom.baseH, transform: `translate(${geom.tx}px, ${geom.ty}px) scale(${view.scale})`, transformOrigin: '0 0' }}
          >
            <img className="cmp-zpane__img" src={url} alt={`${label} ${viewport}`} draggable={false}
              onLoad={(e) => onNatural(platform, { w: e.target.naturalWidth, h: e.target.naturalHeight })} />
            <CommentLayer platform={platform} viewport={viewport} commentMode={commentMode} inv={1 / view.scale} {...commentProps} />
          </div>
        ) : (
          <div className="cmp-shot__missing">{url ? '…' : 'not captured'}</div>
        )}
        {ghost && (
          <div className="cmp-ghost" style={{ left: ghost.gx, top: ghost.gy }} aria-hidden="true">
            <div className="cmp-ghost__ring" />
          </div>
        )}
        {capturing && <div className="viewport__spinner-overlay" aria-hidden="true"><div className="viewport__spinner" /></div>}
      </div>
    </div>
  );
}

export default function CompareDetail() {
  const { id, version } = useParams();
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

  const [comments, setComments] = useState([]);
  const [commentMode, setCommentMode] = useState(false);
  const [draftPin, setDraftPin] = useState(null);
  const [selectedId, setSelectedId] = useState(null);
  const [showResolved, setShowResolved] = useState(true);

  // Synced zoom/pan view + mirrored cursor + per-platform natural image size
  const [view, setView] = useState({ scale: 1, cx: 0.5, cy: 0.5 });
  const [hover, setHover] = useState(null);
  const [animating, setAnimating] = useState(false);
  const animTimer = useRef(null);
  const [natural, setNatural] = useState({ iphone: null, client: null });
  const resetView = useCallback(() => setView({ scale: 1, cx: 0.5, cy: 0.5 }), []);
  const cancelAnim = useCallback(() => { if (animTimer.current) clearTimeout(animTimer.current); setAnimating(false); }, []);
  const onNatural = useCallback((platform, dims) => setNatural((n) => (n[platform] && n[platform].w === dims.w && n[platform].h === dims.h ? n : { ...n, [platform]: dims })), []);

  const unsubRef = useRef(null);
  const canEdit = detail?.canCapture;

  const refetch = async () => {
    try {
      const data = await fetchComparison(id);
      setDetail(data);
      setError(null);
      setDraftJson(JSON.stringify(data.shared ?? {}, null, 2));
      setDraftError(null);
      // No version in the route → jump to the latest version (locks the view).
      if (!version && data.latestVersionId) navigate(`/compare/${id}/${data.latestVersionId}`, { replace: true });
    } catch (err) { setError(err.message); setDetail(null); }
  };
  // Reloads the version-locked view (shots + rating + comments for this version).
  const loadComments = async () => {
    if (!version) return;
    try {
      const v = await fetchVersion(id, version);
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
    if (version) refetch().then(loadComments); else refetch();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id, version]);

  // Reset zoom + remeasure natural when the viewport changes.
  useEffect(() => { resetView(); setNatural({ iphone: null, client: null }); }, [viewport, resetView]);

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
  const shots = useMemo(() => (vdetail ? { iphone: vdetail.shots?.iphone?.url ?? null, client: vdetail.shots?.client?.url ?? null } : null), [vdetail]);
  const shotIds = { iphone: vdetail?.shots?.iphone?.screenshotId ?? null, client: vdetail?.shots?.client?.screenshotId ?? null };
  const capturedFor = (platform) => !!vdetail?.shots?.[platform]?.url;
  const numberOf = useMemo(() => {
    const m = new Map();
    [...comments].sort((a, b) => (a.createdAt < b.createdAt ? -1 : 1)).forEach((c, i) => m.set(c.id, i + 1));
    return m;
  }, [comments]);
  const unresolvedCount = comments.filter((c) => !c.resolved).length;

  const runCapture = async (platform) => {
    if (isCapturing) return;
    setLog([]);
    // Capture the SAME variant as the version currently in view — otherwise the
    // runner falls back to the spec's first variant and the open version never
    // gets a fresh shot (which reads as "capture did nothing").
    const variantName = vdetail?.variantName;
    try {
      const { runId } = await startCompareCapture({ id, viewport, platform, variant: variantName });
      setActiveRun({ id, viewport, runId });
      unsubRef.current = subscribeCapture(runId, {
        onLine: (line) => setLog((p) => [...p, line]),
        onDone: async () => {
          setActiveRun(null);
          bumpShots();
          // Each capture creates a NEW version — jump to the one just captured
          // (newest of this variant+viewport) so its shots are actually shown.
          try {
            const { versions } = await fetchVersions(id);
            const newest = (versions ?? []).find(
              (v) => v.variantName === variantName && v.viewport === viewport,
            );
            if (newest && newest.id !== version) { navigate(`/compare/${id}/${newest.id}`); return; }
          } catch { /* fall through to a plain refetch */ }
          refetch();
        },
        onError: () => setActiveRun(null),
      });
    } catch (err) { setLog((p) => [...p, `Error: ${err.message}`]); }
  };

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
    try { await saveComparisonRating(id, level, version); reload?.(); loadComments(); } catch { setRating(prev); }
  };

  const placeDraft = (platform, vp, x, y) => { setSelectedId(null); setDraftPin({ platform, viewport: vp, x, y }); };
  const submitDraft = async (text) => {
    if (!draftPin) return;
    try { await addComment(id, { ...draftPin, screenshotId: shotIds[draftPin.platform], versionId: version, text, source: 'user' }); setDraftPin(null); await loadComments(); reload?.(); } catch { /* keep */ }
  };
  const addReply = async (commentId, text) => { await replyComment(id, commentId, text, 'user'); await loadComments(); reload?.(); };
  const toggleResolve = async (c) => { await resolveComment(id, c.id, !c.resolved); await loadComments(); reload?.(); };
  const removeComment = async (commentId) => { if (selectedId === commentId) setSelectedId(null); await deleteComment(id, commentId); await loadComments(); reload?.(); };
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

  const copyCommand = async () => {
    const cmd = detail?.command ?? `/compare-adjust ${id}`;
    try { await navigator.clipboard.writeText(cmd); }
    catch { const ta = document.createElement('textarea'); ta.value = cmd; document.body.appendChild(ta); ta.select(); try { document.execCommand('copy'); } catch {} document.body.removeChild(ta); }
    setCopied(true); setTimeout(() => setCopied(false), 1600);
  };

  if (error) {
    return <div className="empty-state"><div>{error}</div><Link to="/compare" className="btn" style={{ marginTop: 12 }}>Back to Compare</Link></div>;
  }
  if (!detail) return <div className="empty-state">Loading…</div>;

  const columnComments = [...comments].sort((a, b) => (a.createdAt < b.createdAt ? -1 : 1)).filter((c) => showResolved || !c.resolved);
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
            <span className="cmp-vp-picker__label">Version</span>
            <span className="cmp-version-pill">
              {vpDims[viewport]?.label ?? viewport ?? '—'}
              {vdetail?.capturedAt ? ` · ${new Date(vdetail.capturedAt).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })}` : ''}
              {vdetail?.gitSha ? ` · ${vdetail.gitSha.slice(0, 7)}${vdetail.gitDirty ? '*' : ''}` : ''}
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
          <button className="btn cmp-icon-btn" onClick={copyCommand} title={`Copy "${detail.command}"`}>
            <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
              <polyline points="4 17 10 11 4 5" /><line x1="12" y1="19" x2="20" y2="19" />
            </svg>
            {copied ? 'Copied!' : 'Command'}
          </button>
          {detail.canCapture && (
            <div className="cmp-capture-group">
              <button className="btn btn--primary" onClick={() => runCapture()} disabled={isCapturing}>{isCapturing ? 'Capturing…' : 'Capture both'}</button>
              <button className="btn btn--mini" onClick={() => runCapture('client')} disabled={isCapturing} title="Web only (fast)">Web</button>
              <button className="btn btn--mini" onClick={() => runCapture('iphone')} disabled={isCapturing} title="iPhone only (slow)">iPhone</button>
            </div>
          )}
        </div>
      </div>

      {detail.projectionError && <div className="error-banner" style={{ margin: 0 }}>Adapter error: {detail.projectionError}</div>}

      {tab === 'preview' ? (
        <div className="cmp-3col">
          <ZoomPane platform="iphone" label="iPhone" url={shots ? `${shots.iphone}?v=${shotsVersion}` : null}
            viewport={viewport} captured={capturedFor('iphone')} natural={natural.iphone} fallbackNatural={vpDims[viewport]} onNatural={onNatural} onReset={resetView}
            view={view} setView={setView} hover={hover} setHover={setHover} capturing={isCapturing}
            animating={animating} clearAnim={cancelAnim}
            commentMode={commentMode} {...commentProps} />
          <ZoomPane platform="client" label="Web" url={shots ? `${shots.client}?v=${shotsVersion}` : null}
            viewport={viewport} captured={capturedFor('client')} natural={natural.client} fallbackNatural={vpDims[viewport]} onNatural={onNatural} onReset={resetView}
            view={view} setView={setView} hover={hover} setHover={setHover} capturing={isCapturing}
            animating={animating} clearAnim={cancelAnim}
            commentMode={commentMode} {...commentProps} />

          <aside className="cmp-comments">
            <div className="cmp-comments__head">
              <span className="cmp-comments__title">Comments</span>
              <label className="cmp-comments__filter"><input type="checkbox" checked={showResolved} onChange={(e) => setShowResolved(e.target.checked)} /> resolved</label>
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
