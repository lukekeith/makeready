import React, { useContext, useEffect, useMemo, useRef, useState, useCallback } from 'react';
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
  // Resolved comments stay in the right column but drop their preview pins —
  // except while selected from the column, so the thread can still be viewed
  // (and reopened) in place.
  const here = comments.filter(
    (c) => c.platform === platform && c.viewport === viewport && (!c.resolved || c.id === selectedId),
  );
  const showDraft = draft && draft.platform === platform && draft.viewport === viewport;

  const selectedBox = here.find((c) => c.id === selectedId && c.targetMeta?.rect)?.targetMeta?.rect;
  const draftBox = showDraft && draft.target?.rect ? draft.target.rect : null;

  return (
    <div className={`cmp-commentlayer${commentMode ? ' cmp-commentlayer--placing' : ''}`} onClick={handleClick}>
      {(selectedBox || draftBox) && (() => {
        const r = draftBox || selectedBox;
        return <div className="cmp-target-box" style={{ left: `${r.x * 100}%`, top: `${r.y * 100}%`, width: `${r.w * 100}%`, height: `${r.h * 100}%` }} aria-hidden="true" />;
      })()}
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
                  {c.targetLabel && <span className="cmp-target-chip" title={c.targetSelector}>◎ {c.targetLabel}</span>}
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
            <div className="cmp-target-chip cmp-target-chip--draft" title={draft.target?.selector}>
              {draft.target ? `◎ ${draft.target.label}` : '◎ resolving element…'}
            </div>
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
  platform, label, url, webUrl, missingLabel, missingAction, viewport, captured, natural, fallbackNatural, onNatural, onReset,
  view, setView, hover, setHover, capturing, animating, clearAnim,
  iframeRef, onHoverInspect, onClearInspect,
  commentMode, ...commentProps
}) {
  const isWeb = !!webUrl;
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
    // In comment mode, highlight the web element under the cursor (works while
    // hovering either pane — the fraction maps onto the aligned web iframe).
    if (commentMode && fx >= 0 && fx <= 1 && fy >= 0 && fy <= 1) onHoverInspect?.(fx, fy);
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
        <span className={`cmp-pane__status ${captured ? 'is-ok' : 'is-missing'}`}>
          {platform === 'client' ? (captured ? 'live' : 'not built') : (captured ? 'captured' : 'not captured')}
        </span>
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
        onMouseLeave={() => { setHover((h) => (h && h.source === platform ? null : h)); if (commentMode) onClearInspect?.(); }}
      >
        {geom && (isWeb ? natural : url) ? (() => {
          // Web (live iframe): keep the element at its natural CSS width so the
          // component lays out at the same width as the iPhone, then fold the
          // fit-to-pane factor into the transform (raster images can just scale,
          // but live DOM must reflow at a fixed width). inv counter-scales pins.
          const fit = geom.baseW / (natural?.w || geom.baseW);
          const effScale = isWeb ? fit * view.scale : view.scale;
          const canvasW = isWeb ? (natural?.w || geom.baseW) : geom.baseW;
          const canvasH = isWeb ? (natural?.h || geom.baseH) : geom.baseH;
          return (
            <div
              className={`cmp-zpane__canvas${animating ? ' cmp-zpane__canvas--anim' : ''}`}
              style={{ width: canvasW, height: canvasH, transform: `translate(${geom.tx}px, ${geom.ty}px) scale(${effScale})`, transformOrigin: '0 0' }}
            >
              {isWeb ? (
                <iframe
                  ref={iframeRef}
                  className="cmp-zpane__iframe"
                  src={webUrl}
                  title={`${label} ${viewport}`}
                  style={{ width: '100%', height: '100%', border: 0, background: '#0d101a', pointerEvents: 'none' }}
                />
              ) : (
                <img className="cmp-zpane__img" src={url} alt={`${label} ${viewport}`} draggable={false}
                  onLoad={(e) => onNatural(platform, { w: e.target.naturalWidth, h: e.target.naturalHeight })} />
              )}
              <CommentLayer platform={platform} viewport={viewport} commentMode={commentMode} inv={1 / effScale} {...commentProps} />
            </div>
          );
        })() : (
          <div className="cmp-shot__missing">
            <span>{(isWeb || url) ? (missingLabel ?? '…') : (missingLabel ?? 'not captured')}</span>
            {missingAction}
          </div>
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
