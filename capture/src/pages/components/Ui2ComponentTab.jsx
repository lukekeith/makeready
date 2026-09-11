// Column 4, UI 2.0 era — the COMPONENT tab on a screen (suite 07 §5, D4).
//
// Its point is to answer "what is that thing?" without leaving the screen you are
// looking at: identity, the frozen artwork, its designed states, a way out to the
// component's own page, and its notes.
//
// Identity comes from the REGISTRY, never from the screen's element map. A chip
// in the Screen tab can select a component the map does not contain — the map
// deliberately omits instances the backfill could not resolve (D5) while the
// Screen tab lists every row in the spec's §4 — so a tab that read the map would
// show an empty state for exactly those components (suite 09 §G-17). The map's
// `resolved` is used only to paint the title instantly while the fetch is in
// flight.
import React, { useCallback, useEffect, useState } from 'react';
import { fetchUi2Detail, fetchUi2Notes, postUi2Note, fetchUi2Mentions } from '../../api.js';
import NoteList from './NoteList.jsx';
import NoteComposer from './NoteComposer.jsx';

export default function Ui2ComponentTab({ refId, seed, canWrite, onOpen, onSelectComponent, onOpenScreen }) {
  const [detail, setDetail] = useState(null);
  const [detailError, setDetailError] = useState(null);
  const [notes, setNotes] = useState(null);
  const [notesError, setNotesError] = useState(null);
  const [mentions, setMentions] = useState([]);
  const [composing, setComposing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState(null);

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

  useEffect(() => { setDetail(null); setNotes(null); setComposing(false); setSaveError(null); }, [refId]);
  useEffect(() => { loadDetail(); }, [loadDetail]);
  useEffect(() => { loadNotes(); }, [loadNotes]);
  // Fetched once per session: ~98 rows, filtered locally, so the typeahead never
  // waits on the network mid-keystroke.
  useEffect(() => {
    let live = true;
    fetchUi2Mentions().then((d) => { if (live) setMentions(d.items ?? []); }).catch(() => {});
    return () => { live = false; };
  }, []);

  if (!refId) {
    return (
      <div className="cmp-cb-col__empty">
        No component selected. Hover the render and click a component, or click one of the
        chips in the Screen tab.
      </div>
    );
  }

  const name = detail?.name ?? seed?.name ?? null;
  const specced = detail ? !!detail.spec || !!detail.contract : !!seed?.specced;
  const built = detail ? !!detail.built : !!seed?.built;
  const hasArtwork = detail ? !!detail.snapshot : !!seed?.hasSnapshot;
  const unknown = !!detailError && !seed;

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

  if (composing) {
    return <NoteComposer target={refId} mentions={mentions} busy={saving} error={saveError} onSave={save} onCancel={() => { setComposing(false); setSaveError(null); }} />;
  }

  return (
    <div className="cmp-ui2d">
      <div className="cmp-ui2c__head">
        <span className="cmp-ui2c__id">{refId}</span>
        <span className="cmp-ui2c__name">{name ?? (unknown ? 'unknown component' : '…')}</span>
      </div>

      <div className="cmp-ui2n__chips">
        {unknown
          ? <span className="cmp-ui2c__status cmp-ui2c__status--queued">not in the registry</span>
          : (
            <>
              <span className={`cmp-ui2n__chip${specced ? ' is-on' : ''}`}>{specced ? 'specced' : 'not specced'}</span>
              <span className={`cmp-ui2n__chip${built ? ' is-on' : ''}`}>{built ? 'built' : 'not built'}</span>
              <span className={`cmp-ui2n__chip${hasArtwork ? ' is-on' : ''}`}>{hasArtwork ? 'artwork' : 'no artwork'}</span>
            </>
          )}
      </div>

      {detail?.snapshot?.url && (
        <img className="cmp-ui2n__art" src={detail.snapshot.url} alt={`${refId} ${name ?? ''}`} />
      )}

      <button type="button" className="btn btn--mini cmp-ui2n__open" disabled={unknown} onClick={() => onOpen(refId)}>
        Open component →
      </button>

      <div className="cmp-ui2n__states">
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

      <NoteList
        notes={notes?.notes ?? []}
        parseError={notes?.parseError ?? null}
        error={notesError}
        onRetry={loadNotes}
        canWrite={canWrite}
        onAdd={() => setComposing(true)}
        onMention={(id) => (/^C-\d{3}$/i.test(id) ? onSelectComponent(id.toUpperCase()) : onOpenScreen(id))}
      />
    </div>
  );
}
