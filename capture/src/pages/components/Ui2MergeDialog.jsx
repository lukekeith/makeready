// The Merge dialog — pick the two sides of `/ui2-component-merge <keep> <duplicate>`.
//
// Merging is destructive in a way no other Prompt entry is: it strikes a registry row out of
// the program. So this one entry does NOT copy a command straight to the clipboard the way
// the /ui2-resolve entries do — it opens here, makes you name both sides, and only then hands
// over the string. The argument ORDER is the whole safety model (the first id survives),
// which is why the two sides are labelled rather than positional, and why either label can be
// clicked to swap the roles.
//
// Layout: the current component spans the top, the picker and its preview sit side by side
// below, and the command runs along the foot. The preview is the point — deciding that two
// rows are duplicates is a VISUAL judgement, and the registry list alone cannot make it. It
// shows one frame per designed state, scrolled through with the wheel.
//
// The picker list is deliberately the same markup as column 1 (`Ui2Tree`): same row classes,
// same section headings, same status dot, same search. Picking a component to merge into is
// the same act as picking one to look at, so it should not look like a different control.
import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import NavSearch from '../../components/NavSearch.jsx';
import CopyCode from '../../components/CopyCode.jsx';
import { fetchUi2Detail } from '../../api.js';

const norm = (s) => (s ?? '').toLowerCase().replace(/[^a-z0-9]/g, '');

/** Ui2Tree's dot, verbatim: nothing specced, spec written, spec + frozen artwork. */
const dotKind = (row) => (row.specced ? (row.hasSnapshot ? 'specced' : 'contract') : (row.hasSnapshot ? 'artwork' : 'registry'));

/** Sections filtered to the rows matching `q`, dropping any left empty, minus `excludeId`. */
function search(sections, q, excludeId) {
  return (sections ?? [])
    .map((s) => ({
      ...s,
      rows: s.rows.filter((r) => r.id !== excludeId && (!q || norm(r.id).includes(q) || norm(r.name).includes(q))),
    }))
    .filter((s) => s.rows.length > 0);
}

/**
 * One frame per designed state: the built render when there is one, else the frozen Figma
 * snapshot. A state with neither is dropped rather than shown as a broken tile — an unspecced
 * row legitimately has nothing to show, and an empty preview says that more clearly than a
 * column of placeholders.
 */
function framesOf(detail) {
  if (!detail) return [];
  return (detail.variants ?? []).flatMap((v) => {
    const shots = v.versions?.[0]?.shots ?? {};
    const built = shots.iphone?.url;
    const design = shots.design?.url;
    const url = built ?? design;
    if (!url) return [];
    return [{ name: v.name, url, kind: built ? 'built render' : 'Figma snapshot' }];
  });
}

/** One side's heading. Clicking it swaps which component is the keeper. */
function RoleHeader({ role, onToggle }) {
  const keep = role === 'keep';
  return (
    <button
      type="button"
      className={`cmp-merge__role cmp-merge__role--${role}`}
      onClick={onToggle}
      title="Click to swap which component is kept"
    >
      <span className="cmp-merge__role-title">{keep ? 'Keep' : 'Duplicate'}</span>
      <span className="cmp-merge__role-desc">
        {keep
          ? 'Features of the duplicate will be merged into this component'
          : 'Features will migrate to other component and then this will be removed'}
      </span>
    </button>
  );
}

/** A registry row, in Ui2Tree's own markup. */
function RegistryRow({ row, active, onClick, asDiv = false }) {
  const inner = (
    <>
      <span className="cmp-ui2__id">{row.id}</span>
      <span className="cmp-ui2__name">{row.name}</span>
      <span className={`cmp-ui2__dot cmp-ui2__dot--${dotKind(row)}`} />
    </>
  );
  const cls = `cmp-ui2__row${active ? ' cmp-ui2__row--active' : ''}${row.specced ? '' : ' cmp-ui2__row--unspecced'}`;
  if (asDiv) return <div className={`${cls} cmp-merge__current-row`} title={row.name}>{inner}</div>;
  return <button type="button" className={cls} onClick={onClick} title={row.name}>{inner}</button>;
}

/**
 * The preview column. Wheel over it steps through the frames.
 *
 * Wheel deltas are accumulated to a threshold, then advance exactly ONE state and reset. Both
 * halves of that matter, because the two input devices are wildly different:
 *
 *   - a mouse notch arrives as a single ~100-120 delta. Draining the accumulator in a loop
 *     would spend it as THREE steps per notch — measured, not theorised: one notch jumped 1/4
 *     to 4/4. Resetting instead of subtracting makes a notch worth one state.
 *   - a trackpad flick arrives as dozens of ~1-10 deltas. Stepping per event would cross the
 *     whole set instantly, which is why the threshold is there at all.
 *
 * Clamps at both ends rather than wrapping, so the counter always says where you are.
 */
function Preview({ detail, loading, error, pickedId }) {
  const frames = useMemo(() => framesOf(detail), [detail]);
  const [i, setI] = useState(0);
  const accum = useRef(0);

  useEffect(() => { setI(0); accum.current = 0; }, [pickedId]);

  const onWheel = useCallback((e) => {
    if (frames.length < 2) return;
    // The dialog itself does not scroll, so nothing is stolen from a parent here.
    e.preventDefault();
    accum.current += e.deltaY;
    const STEP = 40;
    if (Math.abs(accum.current) < STEP) return;
    const dir = accum.current > 0 ? 1 : -1;
    accum.current = 0;
    setI((n) => Math.min(frames.length - 1, Math.max(0, n + dir)));
  }, [frames.length]);

  // A passive listener cannot preventDefault, and React's onWheel is passive — so the handler
  // is attached manually to keep the page from scrolling behind the dialog.
  const ref = useRef(null);
  useEffect(() => {
    const el = ref.current;
    if (!el) return undefined;
    el.addEventListener('wheel', onWheel, { passive: false });
    return () => el.removeEventListener('wheel', onWheel);
  }, [onWheel]);

  const frame = frames[Math.min(i, Math.max(0, frames.length - 1))];

  return (
    <div className="cmp-merge__preview" ref={ref}>
      {!pickedId && <div className="cmp-cb-col__empty">select a component</div>}
      {pickedId && loading && <div className="cmp-cb-col__empty">loading…</div>}
      {pickedId && error && <div className="cmp-cb-col__empty">{error}</div>}
      {pickedId && !loading && !error && !frames.length && (
        <div className="cmp-cb-col__empty">nothing captured yet</div>
      )}
      {frame && (
        <>
          <div className="cmp-merge__shot">
            <img src={frame.url} alt={frame.name} loading="lazy" />
          </div>
          <div className="cmp-merge__shot-meta">
            <span className="cmp-merge__shot-name" title={frame.name}>{frame.name}</span>
            <span className="cmp-merge__shot-kind">{frame.kind}</span>
          </div>
          <div className="cmp-merge__shot-nav">
            {frames.length > 1 ? `${i + 1} / ${frames.length} · scroll to change state` : '1 state'}
          </div>
        </>
      )}
    </div>
  );
}

export default function Ui2MergeDialog({ open, detail, tree, onClose }) {
  // Which role the CURRENT component plays. The other side takes the opposite.
  const [currentRole, setCurrentRole] = useState('keep');
  const [query, setQuery] = useState('');
  const [pickedId, setPickedId] = useState(null);
  const [picked, setPicked] = useState(null);
  const [pickBusy, setPickBusy] = useState(false);
  const [pickError, setPickError] = useState(null);
  const panelRef = useRef(null);

  // Reset per opening: a stale pick from last time would make the copied command wrong in a
  // way that is hard to notice, since the string looks perfectly well-formed.
  useEffect(() => {
    if (open) {
      setCurrentRole('keep'); setQuery('');
      setPickedId(null); setPicked(null); setPickError(null);
    }
  }, [open, detail?.id]);

  // The picked row's full detail, for the preview. Guarded against an out-of-order response
  // overwriting a newer pick.
  useEffect(() => {
    if (!open || !pickedId) { setPicked(null); return undefined; }
    let live = true;
    setPickBusy(true); setPickError(null);
    fetchUi2Detail(pickedId)
      .then((d) => { if (live) { setPicked(d); setPickBusy(false); } })
      .catch((e) => { if (live) { setPickError(e.message); setPickBusy(false); } });
    return () => { live = false; };
  }, [open, pickedId]);

  useEffect(() => {
    if (!open) return undefined;
    const onKey = (e) => { if (e.key === 'Escape') { e.stopPropagation(); onClose?.(); } };
    document.addEventListener('keydown', onKey, true);
    return () => document.removeEventListener('keydown', onKey, true);
  }, [open, onClose]);

  const q = norm(query.trim());
  const sections = useMemo(() => search(tree?.sections, q, detail?.id), [tree, q, detail?.id]);

  if (!open) return null;

  const otherRole = currentRole === 'keep' ? 'duplicate' : 'keep';
  const keepId = currentRole === 'keep' ? detail?.id : pickedId;
  const dupId = currentRole === 'keep' ? pickedId : detail?.id;
  const ready = Boolean(keepId && dupId);
  const command = ready
    ? `/ui2-component-merge ${keepId} ${dupId}`
    : '/ui2-component-merge — pick a component';

  const toggle = () => setCurrentRole((r) => (r === 'keep' ? 'duplicate' : 'keep'));

  return (
    <div
      className="cmp-merge"
      onMouseDown={(e) => { if (!panelRef.current?.contains(e.target)) onClose?.(); }}
    >
      <div className="cmp-merge__panel" ref={panelRef} role="dialog" aria-modal="true" aria-label="Merge components">
        {/* Top — the component the browser is showing. Only its role label changes. */}
        <div className="cmp-merge__top">
          <RoleHeader role={currentRole} onToggle={toggle} />
          <div className="cmp-merge__current">
            {detail
              ? <RegistryRow row={detail} active asDiv />
              : <div className="cmp-cb-col__empty">no component</div>}
            {detail && (
              <div className="cmp-merge__current-meta">
                {detail.stateCount ?? 0} designed state(s)
                {detail.hasSnapshot ? ' · frozen snapshot' : ' · no snapshot'}
                {detail.built ? ' · built' : ' · not built'}
              </div>
            )}
          </div>
        </div>

        <div className="cmp-merge__cols">
          <div className="cmp-merge__col cmp-merge__col--list">
            <RoleHeader role={otherRole} onToggle={toggle} />
            <NavSearch
              placeholder="Filter components…"
              label="Filter components to merge"
              value={query}
              onChange={setQuery}
            />
            <div className="cmp-merge__scroll">
              {!tree && <div className="cmp-cb-col__empty">loading…</div>}
              {tree && !sections.length && <div className="cmp-cb-col__empty">no matching rows</div>}
              {sections.map((section) => (
                <div key={section.name} className="cmp-ui2__section">
                  <div className="cmp-cb-col__title">{section.name}</div>
                  {section.rows.map((row) => (
                    <RegistryRow
                      key={row.id}
                      row={row}
                      active={row.id === pickedId}
                      onClick={() => setPickedId(row.id)}
                    />
                  ))}
                </div>
              ))}
            </div>
          </div>

          <div className="cmp-merge__col cmp-merge__col--preview">
            <div className="cmp-merge__preview-head">Preview</div>
            <Preview detail={picked} loading={pickBusy} error={pickError} pickedId={pickedId} />
          </div>
        </div>

        <div className="cmp-merge__foot">
          <CopyCode value={command} className={`cmp-merge__cmd${ready ? '' : ' cmp-merge__cmd--disabled'}`}>
            {command}
          </CopyCode>
        </div>
      </div>
    </div>
  );
}
