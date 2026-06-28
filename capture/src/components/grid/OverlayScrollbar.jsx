import { useEffect, useRef, useState } from 'react';

// Handle-only overlay scrollbar (transparent track). Overlays the grid edge so
// it never affects layout, fades in ~1s after the cursor enters the grid and
// out ~1s after it leaves, and supports drag-to-scroll. Renders nothing when the
// content doesn't overflow. Must sit inside a position:relative grid root, as a
// sibling of the viewport. Ported from fai-cd packages/ui _internal.
const INSET = 8;
const MIN_HANDLE = 32;

export function OverlayScrollbar({ viewportRef, orientation, recomputeKey }) {
  const horizontal = orientation === 'horizontal';
  const [metrics, setMetrics] = useState({ pos: 0, scrollSize: 0, clientSize: 0 });
  const [visible, setVisible] = useState(false);
  const enterTimer = useRef(null);
  const leaveTimer = useRef(null);
  const draggingRef = useRef(false);

  const read = () => {
    const el = viewportRef.current;
    if (!el) return;
    setMetrics(horizontal
      ? { pos: el.scrollLeft, scrollSize: el.scrollWidth, clientSize: el.clientWidth }
      : { pos: el.scrollTop, scrollSize: el.scrollHeight, clientSize: el.clientHeight });
  };

  useEffect(() => {
    const el = viewportRef.current;
    if (!el) return;
    read();
    el.addEventListener('scroll', read, { passive: true });
    const ro = new ResizeObserver(read);
    ro.observe(el);
    return () => { el.removeEventListener('scroll', read); ro.disconnect(); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [viewportRef, horizontal]);

  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(read, [recomputeKey, horizontal]);

  useEffect(() => {
    const root = viewportRef.current?.parentElement;
    if (!root) return;
    const onEnter = () => {
      if (leaveTimer.current) clearTimeout(leaveTimer.current);
      enterTimer.current = setTimeout(() => setVisible(true), 1000);
    };
    const onLeave = () => {
      if (enterTimer.current) clearTimeout(enterTimer.current);
      if (draggingRef.current) return;
      leaveTimer.current = setTimeout(() => setVisible(false), 1000);
    };
    root.addEventListener('mouseenter', onEnter);
    root.addEventListener('mouseleave', onLeave);
    return () => {
      root.removeEventListener('mouseenter', onEnter);
      root.removeEventListener('mouseleave', onLeave);
      if (enterTimer.current) clearTimeout(enterTimer.current);
      if (leaveTimer.current) clearTimeout(leaveTimer.current);
    };
  }, [viewportRef]);

  const track = Math.max(0, metrics.clientSize - INSET * 2);
  const maxScroll = Math.max(0, metrics.scrollSize - metrics.clientSize);
  const hasOverflow = maxScroll > 1 && track > 0;
  const handleSize = hasOverflow
    ? Math.max(MIN_HANDLE, Math.round(track * (metrics.clientSize / metrics.scrollSize)))
    : 0;
  const travel = Math.max(0, track - handleSize);
  const handlePos = maxScroll > 0 ? (metrics.pos / maxScroll) * travel : 0;

  const onPointerDown = (e) => {
    const el = viewportRef.current;
    if (!el || travel <= 0) return;
    e.preventDefault();
    draggingRef.current = true;
    setVisible(true);
    const start = horizontal ? e.clientX : e.clientY;
    const startScroll = horizontal ? el.scrollLeft : el.scrollTop;
    const perPx = maxScroll / travel;
    const onMove = (ev) => {
      const next = startScroll + ((horizontal ? ev.clientX : ev.clientY) - start) * perPx;
      if (horizontal) el.scrollLeft = next; else el.scrollTop = next;
    };
    const onUp = () => {
      draggingRef.current = false;
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerup', onUp);
    };
    window.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', onUp);
  };

  if (!hasOverflow) return null;

  const handleStyle = horizontal
    ? { width: handleSize, transform: `translateX(${handlePos}px)` }
    : { height: handleSize, transform: `translateY(${handlePos}px)` };

  return (
    <div
      className={`OverlayScrollbar OverlayScrollbar--${orientation}${visible ? ' OverlayScrollbar--visible' : ''}`}
      aria-hidden="true"
    >
      <div className="OverlayScrollbar__Handle" style={handleStyle} onPointerDown={onPointerDown} />
    </div>
  );
}
