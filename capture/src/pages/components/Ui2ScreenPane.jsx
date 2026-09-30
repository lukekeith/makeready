// Column 4 on a UI 2.0 COMPONENT, while a screen is selected — the whole right
// pane, not a tab inside it.
//
// The inverse of Ui2ComponentPane, which owns column 4 on a SCREEN while a
// component is selected. One relationship read from its two ends: a screen's §4
// roll-call says which components it renders, and this pane answers "of the
// screens that render THIS component, what does each do with it".
//
// The pane leads with the relationship rather than with one screen. The screens
// using this component are a LIST, always on screen, so moving between them is
// one click and the whole set is visible without opening anything; the selected
// one then gets its own title block, its frame, and — the point of the pane — the
// component's states that this screen actually renders.
//
// Notes are the SCREEN's notes (docs/ui2/screens/notes/<id>.md), not the
// component's. That is the point of opening a screen from here: a note written
// while looking at a screen binds every component it renders (D3/R13, and the
// /ui2-component-build command's phase 0.7 loads exactly these), so the screens a
// component appears on are where its unread instructions hide.
import React, { useCallback, useEffect, useRef, useState } from 'react';
import { fetchUi2ScreenDetail, fetchUi2Notes, postUi2Note, fetchUi2Mentions } from '../../api.js';
import CopyCode from '../../components/CopyCode.jsx';
import { sampleCall, previewTypeName } from '../../lib/ui2-sample-call.js';
import NoteList from './NoteList.jsx';
import NoteComposer from './NoteComposer.jsx';

const TAB_LABEL = { details: 'Details', notes: 'Notes' };

/** Done. */
function Check() {
  return (
    <svg viewBox="0 0 24 24" width="11" height="11" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <polyline points="4 12.5 9.5 18 20 6" />
    </svg>
  );
}

/** Not done — the chip's tooltip says what is missing, and the row under it
 *  carries the command that fixes it. */
function Unknown() {
  return (
    <svg viewBox="0 0 24 24" width="11" height="11" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <circle cx="12" cy="12" r="9" />
      <path d="M9.4 9.3a2.7 2.7 0 0 1 5.2.9c0 1.8-2.6 2.3-2.6 4" />
      <path d="M12 17.4h.01" />
    </svg>
  );
}

/**
 * The selected screen's frame, cropped square and scrubbed by the pointer.
 *
 * A screen frame is about 1:2, so a square that COVERS it shows roughly half.
 * Rather than shrink it to an unreadable stamp, the pointer's position across the
 * box drives `object-position`, so moving down the square scrolls down the screen
 * — the whole frame is reachable at a legible size in a column with no room for
 * its real height. Leaving the box returns the crop to centre.
 *
 * Movement is pure CSS: `object-position` on a covered image re-crops without
 * re-layout, so scrubbing costs a repaint and nothing else.
 */
function ParallaxFrame({ url, alt, active, onOpen, hint }) {
  const [pos, setPos] = useState({ x: 50, y: 50 });
  const boxRef = useRef(null);

  const onMove = (e) => {
    const r = boxRef.current?.getBoundingClientRect();
    if (!r) return;
    // Clamped rather than raw: a fast pointer leaving the box must not park the
    // crop outside the image.
    const clamp = (n) => Math.max(0, Math.min(100, n));
    setPos({
      x: clamp(((e.clientX - r.left) / r.width) * 100),
      y: clamp(((e.clientY - r.top) / r.height) * 100),
    });
  };

  return (
    <button
      type="button"
      ref={boxRef}
      className={`cmp-ui2p__frame${active ? ' is-open' : ''}`}
      onMouseMove={onMove}
      onMouseLeave={() => setPos({ x: 50, y: 50 })}
      onClick={onOpen}
      title={hint}
    >
      <span className="cmp-ui2p__frame-box">
        <img
          className="cmp-ui2p__frame-img"
          src={url}
          alt={alt}
          style={{ objectPosition: `${pos.x}% ${pos.y}%` }}
          draggable={false}
        />
      </span>
      <span className="cmp-ui2p__frame-hint">
        {active ? 'open in the render area' : 'Open full render'}
      </span>
    </button>
  );
}

export default function Ui2ScreenPane({
  screenId, componentId, componentName, propRows = [], usage, screens = [], canWrite,
  onOpen, onSelect, onClose, onOpenComponent,
  // Open this screen's frame as a render tab, with `componentId`'s instances
  // highlighted. Handed the fetched frame so the tab needs nothing from this pane
  // once it exists — closing the pane must not close the tab.
  onOpenTab, openTabKey = null,
  // Point at one schema's instances on the open render: `onHoverSchema` greens
  // them while the pointer is on the row, `onZoomSchema` frames the first. Both
  // take rects already resolved against the frame, so the layout stays dumb.
  onHoverSchema, onZoomSchema,
}) {
  const [tab, setTab] = useState('details');
  const [detail, setDetail] = useState(null);
  const [detailError, setDetailError] = useState(null);
  const [notes, setNotes] = useState(null);
  const [notesError, setNotesError] = useState(null);
  const [mentions, setMentions] = useState([]);
  const [composing, setComposing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState(null);

  const loadDetail = useCallback(async () => {
    if (!screenId) return;
    try { setDetail(await fetchUi2ScreenDetail(screenId)); setDetailError(null); }
    catch (err) { setDetail(null); setDetailError(err.message); }
  }, [screenId]);

  const loadNotes = useCallback(async () => {
    if (!screenId) return;
    try { setNotes(await fetchUi2Notes(screenId)); setNotesError(null); }
    catch (err) { setNotes(null); setNotesError(err.message); }
  }, [screenId]);

  useEffect(() => { setDetail(null); setNotes(null); setComposing(false); setSaveError(null); }, [screenId]);
  useEffect(() => { loadDetail(); }, [loadDetail]);
  useEffect(() => { loadNotes(); }, [loadNotes]);
  // Fetched once per session and filtered locally, exactly as the component pane
  // does — the note composer's typeahead must never wait on the network.
  useEffect(() => {
    let live = true;
    fetchUi2Mentions().then((d) => { if (live) setMentions(d.items ?? []); }).catch(() => {});
    return () => { live = false; };
  }, []);

  // `usage` is the component detail's own row for this screen, so the title, the
  // counts and the schemas paint instantly while the screen fetch is in flight.
  const name = detail?.name ?? usage?.name ?? null;
  const specced = detail ? !!detail.spec : !!usage?.specced;
  const hasArtwork = detail ? !!detail.snapshot : !!usage?.thumbnail;
  const unknown = !!detailError && !usage;

  const specCmd = (() => {
    const base = detail?.commands?.spec ?? `/ui2-screen ${screenId}`;
    return base.includes('http') ? base : `${base} <figma>`;
  })();
  const steps = [
    {
      key: 'specced',
      label: 'Specced',
      done: specced,
      why: 'No spec yet — a README row with nothing stating its layout, its components or its states.',
      cmd: specCmd,
    },
    {
      key: 'artwork',
      label: 'Artwork',
      done: hasArtwork,
      why: 'No frozen Figma frame on disk. A /ui2-screen run freezes one.',
      cmd: null,
    },
  ];
  const todo = steps.filter((st) => !st.done && st.cmd);

  /** How many instances the element maps resolve on a screen, across its frames.
   *  `null` = no usable map anywhere, which is not the same as zero. */
  const instancesOn = (sc) => {
    const mapped = (sc?.frames ?? []).filter((f) => f.instances !== null);
    return mapped.length ? mapped.reduce((n, f) => n + f.instances, 0) : null;
  };
  const instances = instancesOn(usage);

  /** The states of THIS component that this screen renders — read off the
   *  contract's §3 Consumption column, resolved server-side. */
  const states = usage?.states ?? [];

  /**
   * A schema rendered as its call site — the same derivation the component's own
   * Details tab shows for the selected state, so "what does this screen render"
   * and "what does this state set" read as one thing and are copyable in one
   * click.
   *
   * Assignments prefer the BUILT fixture (the values the preview actually renders
   * with) and fall back to §3's matrix cells. The fixture's values are JSON, so
   * they are handed over as strings for `sampleCall` to read through each prop's
   * declared §4 type — which is what turns `"add"` into `.add` and `false` into
   * `false` rather than `"false"`.
   */
  const callFor = (st) => {
    const assignments = st.props && Object.keys(st.props).length > 0
      ? Object.entries(st.props).map(([k, v]) => ({ name: k, value: typeof v === 'string' ? v : JSON.stringify(v) }))
      : (st.propValues ?? []);
    return sampleCall(previewTypeName(componentName ?? componentId), propRows, assignments);
  };

  /**
   * The instances on the open frame that ARE this schema.
   *
   * Resolvable only because the element maps now carry a `state` per instance
   * (backfilled from Figma 2026-09-12): the map records which variant each
   * instance is, so a schema can point at its own boxes instead of at every
   * instance of the component. An entry with no `state` is not backfilled yet and
   * yields nothing — silence is the right answer for "not recorded", and it is
   * why this degrades per instance rather than per screen.
   */
  const boxesForSchema = (st) => {
    const els = detail?.variants?.[0]?.elements?.elements ?? [];
    const mine = els.filter((e) => e.ref === componentId && e.state === st.name);
    return mine.length
      ? mine.map((e) => ({
        rect: { x: e.x, y: e.y, w: e.w, h: e.h },
        label: st.name,
        tone: 'schema',
      }))
      : null;
  };

  /** Only while THIS screen's tab is the one on screen — greening boxes on a
   *  render that is not showing would be pointing at nothing. */
  const tabOpen = openTabKey === `screen:${screenId}`;

  const frameUrl = detail?.variants?.[0]?.versions?.[0]?.shot
    ?? detail?.snapshot?.url
    ?? usage?.thumbnail
    ?? null;

  /** The frame a click opens: the first, which is the one the square shows. Its
   *  element map is what the render tab highlights from. */
  const openFrame = () => {
    const v = detail?.variants?.[0];
    if (!frameUrl) return;
    onOpenTab?.({
      key: `screen:${screenId}`,
      kind: 'screen',
      title: screenId,
      subtitle: v?.name ?? null,
      badge: 'screen',
      url: frameUrl,
      // Every instance in the frame, kept whole rather than pre-filtered, so the
      // tab can be re-highlighted without being reopened.
      elements: v?.elements?.elements ?? [],
      frameName: v?.name ?? null,
    });
  };

  const save = async (body) => {
    setSaving(true);
    setSaveError(null);
    try {
      // `after` is the newest note this composer opened with, so a note that landed
      // in between is a 409 rather than a silent interleave.
      await postUi2Note(screenId, body, notes?.notes?.[0]?.id ?? null);
      await loadNotes();
      setComposing(false);
    } catch (err) {
      // The text stays in the composer — a failed save must never eat a note.
      setSaveError(err.message);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="cmp-cb-col cmp-cb-col--side cmp-ui2p">
      <div className="cmp-ui2p__head">
        <span className="cmp-ui2p__heading">Related screens</span>
        <button
          type="button"
          className="cmp-ui2p__icon"
          onClick={onClose}
          title="Close — back to the component's panel"
          aria-label="Close the screen pane"
        >
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" aria-hidden="true">
            <path d="M5 5l14 14M19 5L5 19" />
          </svg>
        </button>
      </div>

      {/* Every screen that renders this component, the selected one marked. Ten
          rows tall at most — past that it scrolls, rather than pushing the frame
          and the schemas off the bottom of a column they are the point of. */}
      <div className="cmp-ui2p__screens" role="listbox" aria-label="Screens using this component">
        {screens.map((sc) => {
          const n = instancesOn(sc);
          return (
            <button
              type="button"
              key={sc.id}
              role="option"
              aria-selected={sc.id === screenId}
              className={`cmp-ui2p__screen${sc.id === screenId ? ' is-active' : ''}${sc.specced ? '' : ' is-unspecced'}`}
              onClick={() => onSelect(sc.id)}
              title={sc.specced ? `${sc.id} — renders ${componentId}` : `${sc.id} — README row with no spec yet`}
            >
              {/* Name only. The id is in the title block below, and in the
                  tooltip — in a 26px row it was spending the width the name
                  needs to stay un-truncated. A screen with no spec has no name,
                  and the server already falls that back to the id, so a row is
                  never blank. */}
              <span className="cmp-ui2p__screen-name">{sc.name ?? sc.id}</span>
              {n !== null && n > 0 && <span className="cmp-ui2p__screen-n">×{n}</span>}
            </button>
          );
        })}
        {screens.length === 0 && (
          <div className="cmp-ui2n__muted cmp-ui2p__screens-empty">
            No screen spec names {componentId} in its §4 yet.
          </div>
        )}
      </div>

      {/* The selected screen's own title block. Open-in-new lives here rather than
          in the header: the header now names the LIST, and this is the only
          control in the pane that leaves the page. */}
      <div className="cmp-ui2p__selected">
        <div className="cmp-ui2p__selected-text">
          <span className="cmp-ui2p__id">{screenId}</span>
          <span className="cmp-ui2p__name">{name ?? (unknown ? 'unknown screen' : '…')}</span>
        </div>
        <button
          type="button"
          className="cmp-ui2p__icon"
          disabled={unknown}
          onClick={() => onOpen(screenId)}
          title="Open this screen's own page"
          aria-label="Open this screen's own page"
        >
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M14 4h6v6" />
            <path d="M20 4l-8.5 8.5" />
            <path d="M19 14.5V19a1.5 1.5 0 0 1-1.5 1.5H5A1.5 1.5 0 0 1 3.5 19V6.5A1.5 1.5 0 0 1 5 5h4.5" />
          </svg>
        </button>
      </div>

      <div className="cmp-tab-switch">
        {['details', 'notes'].map((t) => (
          <button
            key={t}
            className={`cmp-tab-switch__btn${tab === t ? ' cmp-tab-switch__btn--active' : ''}`}
            onClick={() => setTab(t)}
          >
            {TAB_LABEL[t]}
          </button>
        ))}
      </div>

      {tab === 'details' && (
        <div className="cmp-ui2d">
          <div className="cmp-ui2n__chips">
            {unknown
              ? <span className="cmp-ui2c__status cmp-ui2c__status--queued">not in the screen table</span>
              : steps.map((st) => (
                <span
                  key={st.key}
                  className={`cmp-ui2n__chip${st.done ? ' is-on' : ' is-todo'}`}
                  title={st.done ? `${st.label} ✓` : st.why}
                >
                  {st.done ? <Check /> : <Unknown />}
                  {st.label}
                </span>
              ))}
          </div>

          {!unknown && todo.length > 0 && (
            <div className="cmp-ui2n__todo">
              {todo.map((st) => (
                <div key={st.key} className="cmp-ui2n__todo-row">
                  <span className="cmp-ui2n__todo-label">{st.label}</span>
                  <CopyCode value={st.cmd} />
                </div>
              ))}
            </div>
          )}

          {detailError && !unknown && (
            <div className="cmp-ui2n__error">
              {detailError}
              <button type="button" className="btn btn--mini" onClick={loadDetail}>Retry</button>
            </div>
          )}

          {frameUrl && (
            <ParallaxFrame
              url={frameUrl}
              alt={`${screenId} ${name ?? ''}`}
              active={openTabKey === `screen:${screenId}`}
              onOpen={openFrame}
              hint={`Open ${screenId} in the render area, with ${componentId}'s instances highlighted`}
            />
          )}

          {/* The schemas: which of this component's designed states this screen
              renders, and the props that produce each. Below the frame because
              that is the order you read them in — see the screen, then see what of
              this component is in it. */}
          <div className="cmp-ui2n__states cmp-ui2n__states--last">
            <div className="cmp-ui2n__title">
              {componentId} here
              {states.length > 1 && <span className="cmp-ui2n__muted"> {states.length} schemas</span>}
            </div>

            {!usage && !detailError && <div className="cmp-ui2n__muted">loading…</div>}

            {usage && states.length === 0 && (
              <p className="cmp-ui2d__prose cmp-ui2d__prose--dim">
                §4 names <code>{componentId}</code> as rendered here, but no state&rsquo;s §3
                consumption cell names this screen — so the contract does not say which variant
                it is. A <code>/ui2-component {componentId}</code> re-run is what records it.
              </p>
            )}

            {states.map((st) => {
              const call = callFor(st);
              const boxes = boxesForSchema(st);
              return (
                <div
                  key={st.slug}
                  className="cmp-ui2p__schema"
                  onMouseEnter={() => tabOpen && boxes && onHoverSchema?.(boxes)}
                  onMouseLeave={() => onHoverSchema?.(null)}
                >
                  <div className="cmp-ui2p__schema-head">
                    <span className="cmp-ui2p__schema-name">{st.name}</span>
                    {/* Frames the first of this schema's instances on the render.
                        Disabled, with the reason in its tooltip, when there is
                        nothing to frame — the tab is closed, or this instance's
                        variant is not in the map yet. */}
                    <button
                      type="button"
                      className="cmp-zpane__reset cmp-ui2p__schema-zoom"
                      disabled={!tabOpen || !boxes}
                      onClick={() => boxes && onZoomSchema?.(boxes[0].rect)}
                      title={!boxes
                        ? `No instance of ${st.name} is recorded in this screen's element map`
                        : !tabOpen
                          ? 'Open the screen in the render area first'
                          : `Zoom to the first ${st.name} on the render`}
                      aria-label={`Zoom to the first ${st.name}`}
                    >
                      <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                        <path d="M8 3H5a2 2 0 0 0-2 2v3" /><path d="M21 8V5a2 2 0 0 0-2-2h-3" />
                        <path d="M3 16v3a2 2 0 0 0 2 2h3" /><path d="M16 21h3a2 2 0 0 0 2-2v-3" />
                      </svg>
                    </button>
                  </div>
                  <CopyCode
                    className="cmp-ui2d__code"
                    value={call}
                    title={`Click to copy the call for ${st.name}`}
                  >
                    <pre className="cmp-ui2d__pre">{call}</pre>
                  </CopyCode>
                </div>
              );
            })}

            {/* The schemas and the instance count come from sources written
                independently — §3's consumption cells by the component's spec run,
                the count by the screen's element map — so where they disagree, say
                so rather than quietly picking one. */}
            {usage && (
              <div className="cmp-ui2p__tally">
                {instances === null
                  ? 'No element map for this screen, so the number of instances is unknown.'
                  : `${instances} instance${instances === 1 ? '' : 's'} mapped on the frame.`}
                {instances !== null && states.length > 0 && instances !== states.length
                  && ' Schemas come from §3 and instances from the element map, so one state can be drawn many times — a mismatch is worth a look, not a reconcile.'}
              </div>
            )}
          </div>
        </div>
      )}

      {tab === 'notes' && (
        composing
          ? <NoteComposer target={screenId} mentions={mentions} busy={saving} error={saveError} onSave={save} onCancel={() => { setComposing(false); setSaveError(null); }} />
          : (
            <NoteList
              notes={notes?.notes ?? []}
              parseError={notes?.parseError ?? null}
              error={notesError}
              onRetry={loadNotes}
              canWrite={canWrite}
              subject="screen"
              onAdd={() => setComposing(true)}
              onMention={(id) => (/^C-\d{3}$/i.test(id) ? onOpenComponent(id.toUpperCase()) : onSelect(id))}
            />
          )
      )}
    </div>
  );
}
