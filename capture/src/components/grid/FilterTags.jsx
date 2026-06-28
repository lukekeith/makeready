import React from 'react';
import { classnames } from '../../util/classnames.js';

// FilterTags — a wrapping flex row laying out a group of FilterTag chips.
// FilterTag — a single pill chip with a label and optional count badge.
// Ported from fai-cd packages/ui primitive/filter-tags + filter-tag.

export const FilterTags = React.forwardRef(function FilterTags(
  { className, children, role = 'group', ...props }, ref,
) {
  return (
    <div ref={ref} role={role} className={classnames('FilterTags', className)} {...props}>
      {children}
    </div>
  );
});

export const FilterTag = React.forwardRef(function FilterTag(
  { label, count, active = false, countLabel, disabled, className, type = 'button', ...props }, ref,
) {
  const hasCount = count !== undefined && count !== null;
  return (
    <button
      ref={ref}
      type={type}
      disabled={disabled}
      aria-pressed={active}
      className={classnames(
        'FilterTag',
        hasCount && 'FilterTag--hasCount',
        active && 'FilterTag--active',
        disabled && 'FilterTag--disabled',
        className,
      )}
      {...props}
    >
      <span className="FilterTag__Label">{label}</span>
      {hasCount ? <span className="FilterTag__Count" aria-label={countLabel}>{count}</span> : null}
    </button>
  );
});
