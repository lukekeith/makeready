// Extracted VERBATIM from pages/compare/CompareDetail.jsx (component-browser
// phase 2.1). Fully CONTROLLED: the host owns {view, hover, natural, animating}
// and the keybindings; this pane computes fit + wheel/drag transforms only.
import React, { useEffect, useMemo, useRef } from 'react';
import { isClick } from '../../lib/hit-test.js';
import useElementSize from './useElementSize.js';
import CommentLayer from './CommentLayer.jsx';

const MIN_SCALE = 0.2;
const MAX_SCALE = 8;
const clamp = (n, lo, hi) => Math.max(lo, Math.min(hi, n));

// One image pane: shares {scale,cx,cy} with its sibling and computes its own
// fit. Emits hover as an image fraction; draws a ghost for the sibling's hover.
export default function ZoomPane({
  platform, label, url, webUrl, missingLabel, missingAction, viewport, captured, natural, fallbackNatural, onNatural, onReset,
  view, setView, hover, setHover, capturing, animating, clearAnim,
  iframeRef, onHoverInspect, onClearInspect,
  // Component targeting on a 2.0 SCREEN render (suite 07 §4.2). All three are
  // optional and every 1.0 caller omits them, so this pane behaves exactly as it
  // did for /compare and the 1.0 component browser.
  onHoverTarget, onClearTarget, onSelectTarget,
  commentMode, ...commentProps
}) {
  const isWeb = !!webUrl;
  const [vpRef, size] = useElementSize();
  const drag = useRef(null);
  const imgRef = useRef(null);

  // `load` does NOT fire for an image the browser already holds, so reading the
  // natural size only in onLoad leaves it unknown whenever the src is unchanged
  // across a state change — every variant switch on a UI 2.0 component (one
  // frozen snapshot serves all of a set's states) and any 1.0 version that
  // copied a prior platform's shot forward. `geom` then falls back to its 1:2
  // default and the image renders squeezed until the element is remounted.
  // Reading it off the element covers both paths; onNatural is idempotent, so
  // running this after every render costs two property reads.
  useEffect(() => {
    const el = imgRef.current;
    if (el?.complete && el.naturalWidth) onNatural(platform, { w: el.naturalWidth, h: el.naturalHeight });
  });

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
    // Where the press started, so mouseup can tell a click from the end of a pan.
    // Panning and component selection share this gesture (both live only when
    // comment mode is OFF), and movement is the only thing that separates them.
    const origin = { x: e.clientX, y: e.clientY };
    const move = (ev) => {
      if (!drag.current || !geom) return;
      const dx = ev.clientX - drag.current.x;
      const dy = ev.clientY - drag.current.y;
      drag.current = { x: ev.clientX, y: ev.clientY };
      setView((v) => ({ ...v, cx: v.cx - dx / (geom.baseW * v.scale), cy: v.cy - dy / (geom.baseH * v.scale) }));
    };
    const up = (ev) => {
      drag.current = null;
      window.removeEventListener('mousemove', move);
      window.removeEventListener('mouseup', up);
      if (!onSelectTarget || !geom || !isClick(origin, { x: ev.clientX, y: ev.clientY })) return;
      // The up point, not the down point: a 1–4px shake should select what the
      // pointer ended on. `vpRef` is the viewport this handler was bound from,
      // so the fractions are computed exactly as onMouseMove does.
      const rect = vpRef.current?.getBoundingClientRect();
      if (!rect) return;
      const { baseW, baseH, tx, ty } = geom;
      const fx = (ev.clientX - rect.left - tx) / (baseW * view.scale);
      const fy = (ev.clientY - rect.top - ty) / (baseH * view.scale);
      if (fx >= 0 && fx <= 1 && fy >= 0 && fy <= 1) onSelectTarget(fx, fy);
    };
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
    // OUT of comment mode, report the component under the cursor on a 2.0 screen.
    // Deliberately a second, independent call rather than a widened condition: the
    // comment-mode branch above is shared with /compare and the 1.0 browser and
    // must keep behaving exactly as it does.
    if (!commentMode && fx >= 0 && fx <= 1 && fy >= 0 && fy <= 1) onHoverTarget?.(fx, fy);
    if (!commentMode && (fx < 0 || fx > 1 || fy < 0 || fy > 1)) onClearTarget?.();
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
          {platform === 'client'
            ? (captured ? 'live' : 'not built')
            : platform === 'design'
              ? (captured ? 'design' : 'no snapshot')
              : (captured ? 'captured' : 'not captured')}
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
        onMouseLeave={() => {
          setHover((h) => (h && h.source === platform ? null : h));
          if (commentMode) onClearInspect?.();
          // Unconditional: R1 wants zero boxes the moment the pointer leaves the
          // render, and the component box lives outside comment mode.
          onClearTarget?.();
        }}
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
                <img ref={imgRef} className="cmp-zpane__img" src={url} alt={`${label} ${viewport}`} draggable={false}
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

