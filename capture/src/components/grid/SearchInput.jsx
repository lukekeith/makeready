import {
  useCallback,
  useEffect,
  useId,
  useRef,
  useState,
} from 'react';
import { Portal } from './Portal.jsx';

// Floating-placeholder + left-icon search field with an optional portaled
// typeahead menu. Ported from fai-cd packages/ui primitive/search-input (TS →
// JSX). The menu auto-positions beneath the input and flips above when needed.

const DefaultSearchIcon = () => (
  <svg className="SearchInput__iconSvg" viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
    <path d="M7 12A5 5 0 1 0 7 2a5 5 0 0 0 0 10ZM10.5 10.5 14 14" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" fill="none" />
  </svg>
);

const GAP = 4;
const MARGIN = 8;

function getMenuPosition(trigger, menuHeight) {
  const vh = window.innerHeight;
  const below = trigger.bottom + GAP;
  const fitsBelow = below + menuHeight <= vh - MARGIN;
  const aboveTop = trigger.top - GAP - menuHeight;
  const placeAbove = !fitsBelow && aboveTop >= MARGIN;
  return {
    top: (placeAbove ? aboveTop : below) + window.scrollY,
    left: trigger.left + window.scrollX,
    width: trigger.width,
  };
}

export function SearchInput({
  value,
  defaultValue,
  onValueChange,
  placeholder = 'Search',
  results = [],
  loading = false,
  emptyMessage,
  onSelect,
  renderResult,
  icon,
  width,
  fullWidth,
  disabled,
  className,
  id,
  onKeyDown,
  onFocus,
  onBlur,
  ...rest
}) {
  const autoId = useId();
  const listId = `${id ?? autoId}-listbox`;

  const isControlled = value !== undefined;
  const [internalValue, setInternalValue] = useState(defaultValue ?? '');
  const query = isControlled ? value : internalValue;

  const [isOpen, setIsOpen] = useState(false);
  const [activeIndex, setActiveIndex] = useState(-1);
  const [menuStyle, setMenuStyle] = useState({});

  const boxRef = useRef(null);
  const menuRef = useRef(null);

  const selectableCount = results.length;
  const hasContent = loading || selectableCount > 0 || (query.trim().length > 0 && !!emptyMessage);
  const menuVisible = isOpen && hasContent && !disabled;

  const setQuery = (next) => {
    if (!isControlled) setInternalValue(next);
    onValueChange?.(next);
  };

  const handleSelect = (result) => {
    if (result.disabled) return;
    setQuery(result.label);
    onSelect?.(result);
    setIsOpen(false);
    setActiveIndex(-1);
  };

  const updatePosition = useCallback(() => {
    const boxEl = boxRef.current;
    if (!boxEl) return;
    const menuHeight = menuRef.current?.getBoundingClientRect().height ?? 0;
    setMenuStyle(getMenuPosition(boxEl.getBoundingClientRect(), menuHeight));
  }, []);

  const setMenuNode = useCallback((node) => {
    menuRef.current = node;
    if (node) updatePosition();
  }, [updatePosition]);

  useEffect(() => {
    if (!menuVisible) return;
    updatePosition();
    const onChange = () => updatePosition();
    window.addEventListener('scroll', onChange, true);
    window.addEventListener('resize', onChange);
    return () => {
      window.removeEventListener('scroll', onChange, true);
      window.removeEventListener('resize', onChange);
    };
  }, [menuVisible, updatePosition, results, loading]);

  useEffect(() => {
    if (!menuVisible || activeIndex < 0) return;
    menuRef.current?.querySelector(`[data-index="${activeIndex}"]`)?.scrollIntoView({ block: 'nearest' });
  }, [activeIndex, menuVisible]);

  const handleKeyDown = (event) => {
    onKeyDown?.(event);
    if (disabled) return;
    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault();
        if (!menuVisible) { setIsOpen(true); return; }
        setActiveIndex((i) => (selectableCount === 0 ? -1 : (i + 1) % selectableCount));
        break;
      case 'ArrowUp':
        event.preventDefault();
        if (!menuVisible) return;
        setActiveIndex((i) => (selectableCount === 0 ? -1 : (i - 1 + selectableCount) % selectableCount));
        break;
      case 'Enter':
        if (menuVisible && activeIndex >= 0 && results[activeIndex]) {
          event.preventDefault();
          handleSelect(results[activeIndex]);
        }
        break;
      case 'Escape':
        if (menuVisible) {
          event.preventDefault();
          setIsOpen(false);
          setActiveIndex(-1);
        }
        break;
      default:
        break;
    }
  };

  const rootStyle = fullWidth
    ? { width: '100%' }
    : width != null
      ? { width: typeof width === 'number' ? `${width}px` : width }
      : undefined;

  const rootClass = [
    'SearchInput',
    disabled ? 'SearchInput--disabled' : '',
    menuVisible ? 'SearchInput--open' : '',
    className ?? '',
  ].filter(Boolean).join(' ');

  return (
    <div className={rootClass} style={rootStyle}>
      <div ref={boxRef} className="SearchInput__box" role="combobox" aria-expanded={menuVisible} aria-controls={listId} aria-haspopup="listbox">
        <span className="SearchInput__icon">{icon ?? <DefaultSearchIcon />}</span>
        <div className="SearchInput__fieldWrap">
          <input
            {...rest}
            id={id}
            type="search"
            className="SearchInput__field"
            value={query}
            disabled={disabled}
            placeholder=" "
            autoComplete="off"
            role="searchbox"
            aria-autocomplete="list"
            aria-controls={listId}
            aria-activedescendant={menuVisible && activeIndex >= 0 ? `${listId}-opt-${activeIndex}` : undefined}
            onChange={(e) => { setQuery(e.target.value); setIsOpen(true); setActiveIndex(-1); }}
            onFocus={(e) => { setIsOpen(true); onFocus?.(e); }}
            onBlur={(e) => { setIsOpen(false); setActiveIndex(-1); onBlur?.(e); }}
            onKeyDown={handleKeyDown}
          />
          <span className="SearchInput__placeholder">{placeholder}</span>
        </div>
      </div>

      {menuVisible && (
        <Portal>
          <div ref={setMenuNode} id={listId} role="listbox" className="SearchInput__menu" style={menuStyle} onMouseDown={(e) => e.preventDefault()}>
            {loading ? (
              <div className="SearchInput__status">Searching…</div>
            ) : selectableCount > 0 ? (
              results.map((result, index) => {
                const active = index === activeIndex;
                const optClass = [
                  'SearchInput__option',
                  active ? 'SearchInput__option--active' : '',
                  result.disabled ? 'SearchInput__option--disabled' : '',
                ].filter(Boolean).join(' ');
                return (
                  <div
                    key={result.id}
                    id={`${listId}-opt-${index}`}
                    data-index={index}
                    role="option"
                    aria-selected={active}
                    aria-disabled={result.disabled || undefined}
                    className={optClass}
                    onMouseEnter={() => setActiveIndex(index)}
                    onMouseDown={() => handleSelect(result)}
                  >
                    {renderResult ? renderResult(result, { active }) : (
                      <>
                        <div className="SearchInput__optionLabel">{result.label}</div>
                        {result.description && <div className="SearchInput__optionDescription">{result.description}</div>}
                      </>
                    )}
                  </div>
                );
              })
            ) : (
              <div className="SearchInput__status">{emptyMessage}</div>
            )}
          </div>
        </Portal>
      )}
    </div>
  );
}
