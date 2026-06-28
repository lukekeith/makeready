import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useVirtualizer } from '@tanstack/react-virtual';
import { OverlayScrollbar } from './OverlayScrollbar.jsx';

// Virtual-scrolling card grid. Ported nearly verbatim from fai-cd
// packages/ui table/card-grid (TS → JSX; default grid-line color adapted to the
// capture dark theme). Lays cells out in lanes via @tanstack/react-virtual so
// thousands of cards scroll smoothly.
const GRID_LINE_WIDTH = 1;

function clampPositive(value, fallback) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return fallback;
  return Math.max(1, Math.floor(value));
}

function useElementWidth(ref) {
  const [width, setWidth] = useState(0);
  useEffect(() => {
    const element = ref.current;
    if (!element) return;
    const updateWidth = () => setWidth(element.getBoundingClientRect().width);
    updateWidth();
    const observer = new ResizeObserver(([entry]) => setWidth(entry.contentRect.width));
    observer.observe(element);
    return () => observer.disconnect();
  }, [ref]);
  return width;
}

function resolveColumnCount({ width, minCellWidth, cellWidth, columnCount }) {
  if (columnCount != null) return clampPositive(columnCount, 1);
  if (width <= 0) return 1;
  const stride = clampPositive(cellWidth ?? minCellWidth ?? 1, 1);
  return Math.max(1, Math.floor((width + GRID_LINE_WIDTH) / (stride + GRID_LINE_WIDTH)));
}

function SkeletonCell() {
  return <div className="CardGrid__SkeletonCell" />;
}

export function CardGrid({
  items,
  renderItem,
  getItemKey,
  totalItemCount,
  onItemsNeeded,
  minCellWidth,
  columnCount,
  cellWidth,
  rowHeight,
  height = '100%',
  gridLineColor = 'var(--border)',
  overscan = 3,
  loading = false,
  skeletonRows = 3,
  renderSkeleton,
  emptyMessage = 'No cards',
  scrollbar = true,
  className,
  ariaLabel = 'Card grid',
}) {
  const viewportRef = useRef(null);
  const viewportWidth = useElementWidth(viewportRef);

  const safeMinCellWidth = clampPositive(minCellWidth, 1);
  const safeRowHeight = clampPositive(rowHeight, 1);
  const fixedCellWidth = cellWidth != null && cellWidth > 0 ? clampPositive(cellWidth, 1) : undefined;
  const resolvedColumnCount = resolveColumnCount({
    width: viewportWidth,
    minCellWidth: safeMinCellWidth,
    cellWidth: fixedCellWidth,
    columnCount,
  });

  const totalItems = totalItemCount ?? items.length;
  const showInitialSkeleton = loading && totalItems === 0;
  const virtualCellSize = safeRowHeight + GRID_LINE_WIDTH;
  const cellWidthCss = fixedCellWidth != null
    ? `${fixedCellWidth}px`
    : `calc((100% - ${(resolvedColumnCount - 1) * GRID_LINE_WIDTH}px) / ${resolvedColumnCount})`;

  const virtualizer = useVirtualizer({
    count: totalItems,
    lanes: resolvedColumnCount,
    getScrollElement: () => viewportRef.current,
    estimateSize: useCallback(() => virtualCellSize, [virtualCellSize]),
    overscan,
  });

  const virtualCells = virtualizer.getVirtualItems();

  useEffect(() => {
    if (!onItemsNeeded || virtualCells.length === 0 || totalItems === 0) return;
    const indexes = virtualCells.map((cell) => cell.index);
    onItemsNeeded(Math.min(...indexes), Math.max(...indexes));
  }, [onItemsNeeded, totalItems, virtualCells]);

  const cellStyle = useCallback((start, columnIndex) => ({
    height: safeRowHeight,
    width: cellWidthCss,
    transform: `translateY(${start}px)`,
    left: `calc(${columnIndex} * (${cellWidthCss} + ${GRID_LINE_WIDTH}px))`,
  }), [cellWidthCss, safeRowHeight]);

  const staticCellStyle = useCallback((index) => {
    const columnIndex = index % resolvedColumnCount;
    const stackIndex = Math.floor(index / resolvedColumnCount);
    return {
      height: safeRowHeight,
      width: cellWidthCss,
      transform: `translateY(${stackIndex * virtualCellSize}px)`,
      left: `calc(${columnIndex} * (${cellWidthCss} + ${GRID_LINE_WIDTH}px))`,
    };
  }, [cellWidthCss, resolvedColumnCount, safeRowHeight, virtualCellSize]);

  const renderPlaceholder = (index, meta) => (
    renderSkeleton ? renderSkeleton(index, meta) : <SkeletonCell />
  );

  const cls = ['CardGrid', className ?? ''].filter(Boolean).join(' ');
  const rootStyle = { height, '--CardGrid-gridLineColor': gridLineColor };

  return (
    <div className={cls} style={rootStyle}>
      <div ref={viewportRef} className="CardGrid__Viewport" role="grid" aria-label={ariaLabel}>
        {showInitialSkeleton ? (
          <div className="CardGrid__Cells" style={{ height: (skeletonRows * virtualCellSize) - GRID_LINE_WIDTH }}>
            {Array.from({ length: skeletonRows * resolvedColumnCount }, (_, index) => {
              const columnIndex = index % resolvedColumnCount;
              const meta = { cellIndex: index, columnIndex };
              return (
                <div key={index} className="CardGrid__Cell" style={staticCellStyle(index)} role="gridcell" aria-colindex={columnIndex + 1}>
                  {renderPlaceholder(index, meta)}
                </div>
              );
            })}
          </div>
        ) : totalItems === 0 ? (
          <div className="CardGrid__Empty">{emptyMessage}</div>
        ) : (
          <div className="CardGrid__Cells" style={{ height: virtualizer.getTotalSize() }}>
            {virtualCells.map((virtualCell) => {
              const itemIndex = virtualCell.index;
              const item = items[itemIndex];
              const columnIndex = virtualCell.lane;
              const meta = { cellIndex: itemIndex, columnIndex };
              const key = item == null ? `placeholder-${itemIndex}` : getItemKey?.(item, itemIndex) ?? String(itemIndex);
              return (
                <div key={key} className="CardGrid__Cell" style={cellStyle(virtualCell.start, columnIndex)} role="gridcell" aria-colindex={columnIndex + 1}>
                  {item == null ? renderPlaceholder(itemIndex, meta) : renderItem(item, itemIndex, meta)}
                </div>
              );
            })}
          </div>
        )}
      </div>

      {scrollbar && (
        <OverlayScrollbar orientation="vertical" viewportRef={viewportRef} recomputeKey={virtualizer.getTotalSize()} />
      )}
    </div>
  );
}
