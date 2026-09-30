// Column 4 on a UI 2.0 SCREEN, while a component is selected — the whole right
// pane, not a tab inside it (suite 07 §5, D4).
//
// The Component tab it replaces had to share four tab slots with the screen's own
// spec and comments, which left the thing you had just clicked on squeezed into a
// third of the column. A selection now OWNS the column: the title is the picker
// (every component in the screen's §4 roll-call, so you can walk the screen from
// the pane itself), the close icon puts the screen's own panel back, and the
// pane's two tabs — Details and Notes — are the only two things a component has
// to say here.
//
// Identity still comes from the REGISTRY, never from the screen's element map. A
// chip (or this picker) can select a component the map does not contain — the map
// deliberately omits instances the backfill could not resolve (D5) while the
// screen spec lists every row in §4 — so a pane that read the map would show an
// empty state for exactly those components (suite 09 §G-17). The map's `resolved`
// is used only to paint the title instantly while the fetch is in flight.
import React, { useCallback, useEffect, useRef, useState } from 'react';
import { fetchUi2Detail, fetchUi2Notes, postUi2Note, fetchUi2Mentions } from '../../api.js';
import CopyCode from '../../components/CopyCode.jsx';
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

/** Not done — a question mark, because the chip's tooltip explains what is missing
 *  and the row under it carries the command that fixes it. */
function Unknown() {
  return (
    <svg viewBox="0 0 24 24" width="11" height="11" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <circle cx="12" cy="12" r="9" />
      <path d="M9.4 9.3a2.7 2.7 0 0 1 5.2.9c0 1.8-2.6 2.3-2.6 4" />
      <path d="M12 17.4h.01" />
    </svg>
  );
}

function Chevron() {
  return (
    <svg viewBox="0 0 24 24" width="10" height="10" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <polyline points="6 9 12 15 18 9" />
    </svg>
  );
}

export default function Ui2ComponentPane({
  refId, seed, canWrite, components = [], onOpen, onSelect, onClose, onOpenScreen,
  // The mirror of what the screen pane does with a screen's frame: open this
  // component's own artwork as a render tab beside the screen, so you can look at
  // the component full-size without leaving the screen you are reading.
  onOpenTab, openTabKey = null,
}) {
  const [tab, setTab] = useState('details');
  const [pickerOpen, setPickerOpen] = useState(false);
  const [detail, setDetail] = useState(null);
  const [detailError, setDetailError] = useState(null);
  const [notes, setNotes] = useState(null);
  const [notesError, setNotesError] = useState(null);
  const [mentions, setMentions] = useState([]);
  const [composing, setComposing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState(null);
  const pickerRef = useRef(null);

  const loadDetail = useCallback(async () => {
    if (!refId) return;
    try { setDetail(await fetchUi2Detail(refId)); setDetailError(null); }
    catch (err) { setDetail(null); setDetailError(err.message); }
  }, [refId]);

  const loadNotes = useCallback(async () => {
    if (!refId) return;
    try { setNotes(await fetchUi2Notes(refId)); setNotesError(null); }
    catch (err) { setNotes(null); setNotesError(err.message); }
  }, [refId]);

  useEffect(() => { setDetail(null); setNotes(null); setComposing(false); setSaveError(null); setPickerOpen(false); }, [refId]);
  useEffect(() => { loadDetail(); }, [loadDetail]);
  useEffect(() => { loadNotes(); }, [loadNotes]);
  // Fetched once per session: ~98 rows, filtered locally, so the typeahead never
  // waits on the network mid-keystroke.
  useEffect(() => {
    let live = true;
    fetchUi2Mentions().then((d) => { if (live) setMentions(d.items ?? []); }).catch(() => {});
    return () => { live = false; };
  }, []);

  // Escape closes the picker before it closes anything else; click-outside is the
  // other way out. Neither dismisses the pane — only the close icon and a click
  // on empty render do that, so the selection is never lost by accident.
  useEffect(() => {
    if (!pickerOpen) return undefined;
    const onDown = (e) => { if (!pickerRef.current?.contains(e.target)) setPickerOpen(false); };
    const onKey = (e) => { if (e.key === 'Escape') { e.stopPropagation(); setPickerOpen(false); } };
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey, true);
    return () => { document.removeEventListener('mousedown', onDown); document.removeEventListener('keydown', onKey, true); };
  }, [pickerOpen]);

  const name = detail?.name ?? seed?.name ?? null;
  const specced = detail ? !!detail.spec || !!detail.contract : !!seed?.specced;
  const built = detail ? !!detail.built : !!seed?.built;
  const hasArtwork = detail ? !!detail.snapshot : !!seed?.hasSnapshot;
  const unknown = !!detailError && !seed;

  /**
   * The three completion indicators, as ONE model so they read as one language:
   * every step keeps its noun in both states and the icon carries done-ness —
   * "not specced" / "built" / "no artwork" were three different grammars for the
   * same question. An unfinished step is amber, explains itself on hover, and
   * where a command performs it, offers that command to copy underneath.
   *
   * `commands.spec` already carries the resolved node URL when the registry
   * determines one (server: a placeholder there would copy something you then
   * have to hand-edit). Only when it does not is `<figma>` appended, so the
   * copied string always says what it still needs.
   */
  const specCmd = (() => {
    const base = detail?.commands?.spec ?? `/ui2-component ${refId}`;
    return base.includes('http') ? base : `${base} <figma>`;
  })();
  const steps = [
    {
      key: 'specced',
      label: 'Specced',
      done: specced,
      why: 'No contract yet — a registry row with nothing stating its variants, states or props.',
      cmd: specCmd,
    },
    {
      key: 'built',
      label: 'Built',
      done: built,
      why: 'No SwiftUI preview yet — nothing renders beside the Figma snapshot for the browser to diff.',
      cmd: `/ui2-component-build ${refId}`,
    },
    {
      key: 'artwork',
      label: 'Artwork',
      done: hasArtwork,
      // No slash command of its own: a spec run freezes the snapshot, and
      // Refresh snapshot on the render re-freezes it.
      why: 'No frozen Figma snapshot on disk. A /ui2-component run freezes one; Refresh snapshot on the render re-freezes it.',
      cmd: null,
    },
  ];
  const todo = steps.filter((st) => !st.done && st.cmd);

  const save = async (body) => {
    setSaving(true);
    setSaveError(null);
    try {
      // `after` is the newest note this composer was opened with, so a note that
      // landed in between is a 409 rather than a silent interleave.
      await postUi2Note(refId, body, notes?.notes?.[0]?.id ?? null);
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
        <div className="cmp-ui2p__picker" ref={pickerRef}>
          <button
            type="button"
            className="cmp-ui2p__title"
            aria-haspopup="listbox"
            aria-expanded={pickerOpen}
            disabled={!components.length}
            onClick={() => setPickerOpen((o) => !o)}
            title={components.length ? 'Switch to another component in this screen' : 'This screen lists no components'}
          >
            <span className="cmp-ui2p__id">{refId}</span>
            <span className="cmp-ui2p__name">{name ?? (unknown ? 'unknown component' : '…')}</span>
            {!!components.length && <Chevron />}
          </button>
          {pickerOpen && !!components.length && (
            <div className="cmp-ui2p__menu" role="listbox">
              {components.map((c) => (
                <button
                  type="button"
                  key={c.id}
                  role="option"
                  aria-selected={c.id === refId}
                  className={`cmp-ui2p__opt${c.id === refId ? ' is-active' : ''}${c.specced ? '' : ' cmp-ui2p__opt--unspecced'}`}
                  onClick={() => { setPickerOpen(false); onSelect(c.id); }}
                  title={c.specced ? 'specced' : 'registry row only — no contract yet'}
                >
                  <span className="cmp-ui2p__optid">{c.id}</span>
                  <span className="cmp-ui2p__optname">{c.name ?? ''}</span>
                </button>
              ))}
            </div>
          )}
        </div>
        {/* Open-in-new, not "Open component →": the pane's header has room for a
            glyph and none for a sentence, and the action is the ordinary one. */}
        <button
          type="button"
          className="cmp-ui2p__icon"
          disabled={unknown}
          onClick={() => onOpen(refId)}
          title="Open this component's own page"
          aria-label="Open this component's own page"
        >
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M14 4h6v6" />
            <path d="M20 4l-8.5 8.5" />
            <path d="M19 14.5V19a1.5 1.5 0 0 1-1.5 1.5H5A1.5 1.5 0 0 1 3.5 19V6.5A1.5 1.5 0 0 1 5 5h4.5" />
          </svg>
        </button>
        <button
          type="button"
          className="cmp-ui2p__icon"
          onClick={onClose}
          title="Close — back to the screen's panel"
          aria-label="Close the component pane"
        >
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" aria-hidden="true">
            <path d="M5 5l14 14M19 5L5 19" />
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
              ? <span className="cmp-ui2c__status cmp-ui2c__status--queued">not in the registry</span>
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

          {detail?.snapshot?.url && (
            <button
              type="button"
              className={`cmp-ui2p__screenshot cmp-ui2p__screenshot--wide${openTabKey === `component:${refId}` ? ' is-open' : ''}`}
              onClick={() => onOpenTab?.({
                key: `component:${refId}`,
                kind: 'component',
                title: refId,
                subtitle: name ?? null,
                badge: 'component',
                url: detail.snapshot.url,
              })}
              title={`Open ${refId} full-size in the render area`}
            >
              <img className="cmp-ui2n__art" src={detail.snapshot.url} alt={`${refId} ${name ?? ''}`} />
              <span className="cmp-ui2p__screenshot-hint">
                {openTabKey === `component:${refId}` ? 'open in the render area' : 'Open full render'}
              </span>
            </button>
          )}

          <div className="cmp-ui2n__states cmp-ui2n__states--last">
            <div className="cmp-ui2n__title">Designed states</div>
            {detailError && !unknown && (
              <div className="cmp-ui2n__error">
                {detailError}
                <button type="button" className="btn btn--mini" onClick={loadDetail}>Retry</button>
              </div>
            )}
            {!detail && !detailError && <div className="cmp-ui2n__muted">loading states…</div>}
            {detail && !detail.variants?.length && <div className="cmp-ui2n__muted">not specced yet</div>}
            {detail?.variants?.map((v) => (
              <div key={v.name} className="cmp-ui2n__state">
                <span className="cmp-ui2n__state-name">{v.name}</span>
                {v.consumption && <span className="cmp-ui2n__muted">{v.consumption}</span>}
              </div>
            ))}
          </div>
        </div>
      )}

      {tab === 'notes' && (
        composing
          ? <NoteComposer target={refId} mentions={mentions} busy={saving} error={saveError} onSave={save} onCancel={() => { setComposing(false); setSaveError(null); }} />
          : (
            <NoteList
              notes={notes?.notes ?? []}
              parseError={notes?.parseError ?? null}
              error={notesError}
              onRetry={loadNotes}
              canWrite={canWrite}
              onAdd={() => setComposing(true)}
              onMention={(id) => (/^C-\d{3}$/i.test(id) ? onSelect(id.toUpperCase()) : onOpenScreen(id))}
            />
          )
      )}
    </div>
  );
}
