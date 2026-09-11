// The UI 2.0 era of the components browser — same 4-column shell, different
// source of truth.
//
// 1.0 (ComponentsLayout) browses BUILT Swift components: the render is a
// simulator capture and the second side-panel tab is its fixture data. 2.0
// browses SPECCED components from docs/ui2: a registry row is the component, its
// contract's designed states are the variants, and the render is the frozen
// Figma snapshot — registered as a `design` screenshot so the version timeline
// and pinned comments behave exactly as they do on the 1.0 side (there is no
// 2.0 code to capture yet; when there is, the same columns show it).
import React, { useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { CaptureContext } from '../../App.jsx';
import AppHeader from '../../components/AppHeader.jsx';
import ConfirmDialog from '../../components/ConfirmDialog.jsx';
import {
  fetchUi2Tree,
  fetchUi2Detail,
  fetchUi2Screens,
  fetchUi2ScreenDetail,
  fetchUi2Version,
  refreshUi2Snapshot,
  saveUi2Fixture,
  deleteUi2Version,
  captureUi2,
  subscribeCapture,
  addComment,
  replyComment,
  resolveComment,
  deleteComment,
} from '../../api.js';
import Ui2Tree from './Ui2Tree.jsx';
import Ui2SpecChecklist from './Ui2SpecChecklist.jsx';
import VariantList from './VariantList.jsx';
import RenderPane from './RenderPane.jsx';
import SidePanel from './SidePanel.jsx';

const ID_RE = /^C-\d{3}$/i;
/** Component or screen? The two registries share one route space, and their id
 *  shapes are disjoint by construction: a component is always `C-###`, a screen
 *  is always a kebab word from the README table. So the URL alone says which
 *  endpoint to ask, with no lookup and no ambiguity. */
const kindOf = (id) => (ID_RE.test(id ?? '') ? 'component' : 'screen');

/** `<C-###|screen-id>[/<variant-slug>]`. The slug is the canonical key
 *  (lowercase, dashed, never percent-encoded), but links made before slugs
 *  existed carry the state's display name — which could hold slashes — so
 *  everything after the id is kept as one string and resolved against slug
 *  first, name second. */
function parseSub(sub) {
  const segs = (sub ?? '').split('/').filter(Boolean).map(decodeURIComponent);
  if (!segs.length) return { id: null, key: null, kind: null };
  const kind = kindOf(segs[0]);
  return {
    id: kind === 'component' ? segs[0].toUpperCase() : segs[0],
    key: segs.slice(1).join('/') || null,
    kind,
  };
}

const RENDER_LABELS = {
  recapture: 'Refresh snapshot',
  busy: 'Refreshing…',
  empty: 'no frozen snapshot',
  emptyAction: 'Refresh snapshot',
  current: 'Frozen Figma snapshot',
};

export default function Ui2Layout({ sub = '', header = null }) {
  const { subscribeLive } = useContext(CaptureContext);
  const navigate = useNavigate();

  const [treeData, setTreeData] = useState(null);
  const [screenData, setScreenData] = useState(null);
  const [treeError, setTreeError] = useState(null);
  const [detail, setDetail] = useState(null);
  const [detailError, setDetailError] = useState(null);
  const [versionId, setVersionId] = useState(null); // null = current
  const [vdata, setVdata] = useState(null);
  const [shotsVersion, setShotsVersion] = useState(() => Date.now());

  // Comment state (host-owned, mirroring ComponentsLayout)
  const [commentMode, setCommentMode] = useState(false);
  const [draftPin, setDraftPin] = useState(null);
  const [selectedCommentId, setSelectedCommentId] = useState(null);

  const [busy, setBusy] = useState(false);
  const [log, setLog] = useState([]);
  const [platform, setPlatform] = useState('design');
  const unsubRef = useRef(null);

  const { id, key, kind } = useMemo(() => parseSub(sub), [sub]);
  const isScreen = kind === 'screen';
  const variantPath = useCallback((v) => `/components/2.0/${id}/${v.slug}`, [id]);

  const loadTree = useCallback(async () => {
    // Both registries feed one column, so both are fetched together and one
    // failure surfaces as one banner — a half-loaded tree would silently look
    // like "there are no screens".
    try {
      const [components, screens] = await Promise.all([fetchUi2Tree(), fetchUi2Screens()]);
      setTreeData(components); setScreenData(screens); setTreeError(null);
    } catch (err) { setTreeError(err.message); }
  }, []);
  useEffect(() => { loadTree(); }, [loadTree]);

  const loadDetail = useCallback(async () => {
    if (!id) { setDetail(null); setDetailError(null); return; }
    try { setDetail(await (isScreen ? fetchUi2ScreenDetail(id) : fetchUi2Detail(id))); setDetailError(null); }
    catch (err) { setDetail(null); setDetailError(err.message); }
  }, [id, isScreen]);
  useEffect(() => { loadDetail(); }, [loadDetail, shotsVersion]);

  const activeVariant = useMemo(() => {
    if (!detail?.variants?.length) return null;
    return detail.variants.find((v) => v.slug === key)
      ?? detail.variants.find((v) => v.name === key) // pre-slug link
      ?? detail.variants[0];
  }, [detail, key]);

  // Land on the first state when none is named, and rewrite any link that named
  // one another way (a pre-slug display name, or a state the contract has since
  // relabelled) to the canonical slug — so the address bar always shows the
  // clean form and a stale bookmark still resolves.
  useEffect(() => {
    if (!id || detail?.id !== id || !activeVariant) return;
    if (key !== activeVariant.slug) navigate(variantPath(activeVariant), { replace: true });
  }, [id, key, detail, activeVariant, navigate, variantPath]);

  useEffect(() => { setVersionId(null); setSelectedCommentId(null); setDraftPin(null); setCommentMode(false); }, [id, key]);
  // Switching components: an unbuilt component has no `iphone` render, so the
  // toggle would be left pointing at a render that doesn't exist.
  // A BUILT row opens on its built render: that is the thing being reviewed,
  // and the Figma side is one identical whole-set snapshot shared by every
  // state (syncUi2Row registers the same PNG under all of them), so defaulting
  // to `design` made every state look the same and hid the render entirely.
  // A row with no fixture still opens on Figma — it has nothing else.
  useEffect(() => { setPlatform(detail?.built ? 'iphone' : 'design'); }, [id, detail?.built]);

  const activeVersionId = versionId ?? activeVariant?.versions?.[0]?.versionId ?? null;
  const loadVdata = useCallback(async () => {
    if (!activeVersionId) { setVdata(null); return; }
    try { setVdata(await fetchUi2Version(activeVersionId)); }
    catch { setVdata(null); }
  }, [activeVersionId]);
  useEffect(() => { loadVdata(); }, [loadVdata, shotsVersion]);

  const bumpShots = useCallback(() => { setShotsVersion(Date.now()); loadTree(); }, [loadTree]);
  useEffect(() => subscribeLive(() => bumpShots()), [subscribeLive, bumpShots]);

  // The screenshot ACTUALLY shown for the toggle's current selection — falls
  // back to `design` when this version has no shot for the selected platform
  // (an older version captured before the component was built), and flags that
  // fallback so nothing downstream (the pane, a new comment) mistakes the
  // Figma image for a built one. `vdata.shots` is only present once the server
  // knows about both platforms (Task 5 fix round 1); guard for the shape's
  // absence rather than assume it.
  const activeShot = useMemo(() => {
    const shots = vdata?.shots;
    if (!shots) return { url: vdata?.shot ?? null, screenshotId: vdata?.screenshotId ?? null, platform: 'design', fallback: false };
    const chosen = shots[platform];
    if (chosen?.url) return { url: chosen.url, screenshotId: chosen.screenshotId, platform, fallback: false };
    const design = shots.design;
    return { url: design?.url ?? null, screenshotId: design?.screenshotId ?? null, platform: 'design', fallback: platform !== 'design' };
  }, [vdata, platform]);

  // ── Comments (anchored to the viewed design version) ──
  const canComment = !!detail?.canCapture && !!activeShot.url;
  const refreshComments = useCallback(async () => { await loadVdata(); await loadDetail(); loadTree(); }, [loadVdata, loadDetail, loadTree]);

  // ── Element targeting (the 2.0 hit-test oracle) ──
  //
  // The 1.0 side hit-tests a hidden live Vue twin (ComponentsLayout). A 2.0
  // component has no twin — so its BUILT render ships its own geometry instead:
  // the capture harness writes each annotated part's rect beside the PNG
  // (UI2Element.swift / CaptureRunner.writeElementMap) and the server hands it
  // over with the version. That makes the hit test local and synchronous, with
  // no iframe, no postMessage and no 600ms timeout to lose a race with.
  //
  // Only the built render has parts: the Figma snapshot is one flat image, and
  // an unbuilt component has no render at all — both leave `elements` null and
  // behave exactly as they did before.
  const elements = activeShot.platform === 'iphone' ? (vdata?.elements?.elements ?? null) : null;
  const [hoverTarget, setHoverTarget] = useState(null);
  // The Layout tab drives its own box: it works outside comment mode (where
  // `hoverTarget` is deliberately cleared), and it is set from a tree row
  // rather than from a pointer over the render.
  const [inspectBox, setInspectBox] = useState(null);

  /** Smallest annotated part containing the point — the deepest one, since a
   *  child's rect is inside its parent's. Reversed, that is the path from the
   *  component down to the part, which is what the comment records.
   *
   *  Ties are real and common: a slot holding exactly one control has that
   *  control's rect exactly (C-040's `Leading` and its `GlyphButton (back)`),
   *  and the useful label is the inner one. The capture harness emits a part
   *  after everything inside it (`transformAnchorPreference` appends the
   *  ancestor to its subtree's value), so equal areas arrive deepest-first —
   *  and a stable sort keeps them that way. */
  const hitTest = useCallback((fx, fy) => {
    if (!elements?.length) return null;
    const hits = elements.filter((e) => fx >= e.x && fx <= e.x + e.w && fy >= e.y && fy <= e.y + e.h);
    if (!hits.length) return null;
    const inward = [...hits].sort((a, b) => (a.w * a.h) - (b.w * b.h)); // deepest first
    const el = inward[0];
    const path = [...inward].reverse().map((e) => e.name);              // component → part
    return { selector: path.join(' › '), label: el.name, path, rect: { x: el.x, y: el.y, w: el.w, h: el.h } };
  }, [elements]);

  // Suspended while a draft composer or a thread is open — the target box stays
  // pinned to THAT comment's element instead (CommentLayer's selectedBox).
  const hoverInspect = useCallback((fx, fy) => {
    if (draftPin || selectedCommentId) return;
    setHoverTarget(hitTest(fx, fy));
  }, [draftPin, selectedCommentId, hitTest]);
  const clearInspect = useCallback(() => setHoverTarget(null), []);
  useEffect(() => {
    if (!commentMode || draftPin || selectedCommentId) setHoverTarget(null);
  }, [commentMode, draftPin, selectedCommentId]);

  // `platform` here is whatever RenderPane's ZoomPane is actually displaying
  // (the SHOWN platform, post-fallback) — not necessarily the toggle's raw
  // selection — so the pin is tagged with the image it was actually placed on.
  const placeDraft = (platform, viewport, x, y) => {
    setSelectedCommentId(null);
    setHoverTarget(null);
    // No element map (Figma snapshot, or a render captured before the harness
    // emitted one) → no `target` key at all, so the composer shows no chip
    // rather than a stuck "resolving element…". A map that simply missed at
    // this point resolves to undefined, which reads the same way.
    const target = elements?.length ? hitTest(x, y) : null;
    setDraftPin({ platform, viewport, x, y, ...(elements?.length ? { target: target ?? undefined } : {}) });
  };
  const submitDraft = async (text) => {
    if (!draftPin || !detail?.comparisonId) return;
    try {
      await addComment(detail.comparisonId, {
        variantName: vdata?.variantName ?? activeVariant?.name ?? 'default',
        // The platform the pin was actually dropped on (see placeDraft) —
        // falls back to the shown platform if a caller ever omits it.
        platform: draftPin.platform ?? activeShot.platform,
        viewport: draftPin.viewport,
        x: draftPin.x,
        y: draftPin.y,
        screenshotId: activeShot.screenshotId ?? undefined,
        text,
        source: 'user',
        // The SwiftUI part the pin landed on — same three columns the 1.0 side
        // fills from its web twin, so /component-resolve reads one shape.
        targetSelector: draftPin.target?.selector,
        targetLabel: draftPin.target?.label,
        targetMeta: draftPin.target
          ? { rect: draftPin.target.rect, path: draftPin.target.path, source: 'swiftui' }
          : undefined,
      });
      setDraftPin(null); setCommentMode(false); setHoverTarget(null);
      await refreshComments();
    } catch { /* keep the draft so the text isn't lost */ }
  };
  const onReply = async (commentId, text) => { await replyComment(detail.comparisonId, commentId, text, 'user'); await refreshComments(); };
  const onResolve = async (c) => { await resolveComment(detail.comparisonId, c.id, !c.resolved); await refreshComments(); };
  const onDelete = async (commentId) => {
    if (selectedCommentId === commentId) setSelectedCommentId(null);
    await deleteComment(detail.comparisonId, commentId);
    await refreshComments();
  };

  // "Recapture" for a spec: re-read the frozen PNG; a /ui2-component re-run that
  // refreshed it appends a design version.
  const runRefresh = async () => {
    if (busy || !detail?.id) return;
    setBusy(true); setLog([]);
    try {
      const r = await refreshUi2Snapshot(detail.id);
      setLog([r.created > 0
        ? `snapshot changed — ${r.created} design version(s) added`
        : 'snapshot unchanged (same sha) — no new version']);
      bumpShots();
    } catch (err) {
      setLog([`Error: ${err.message}`]);
    } finally { setBusy(false); }
  };

  // A built component's "recapture" re-runs the simulator; an unbuilt one has
  // only the frozen snapshot to re-read. `allVariants` is the split-button's
  // second item: `*` sends the runner every state in the fixture (undesigned
  // states aren't in it), which is minutes per state — hence not the default.
  const runCapture = async ({ allVariants = false } = {}) => {
    if (busy || !detail?.built) return;
    if (!allVariants && !activeVariant) return;
    setBusy(true); setLog([]);
    try {
      const { runId } = await captureUi2(detail.id, allVariants ? '*' : activeVariant.slug);
      unsubRef.current = subscribeCapture(runId, {
        onLine: (line) => setLog((l) => [...l, line]),
        onDone: () => { setBusy(false); bumpShots(); },
        onError: (err) => { setLog((l) => [...l, `Error: ${err}`]); setBusy(false); },
      });
    } catch (err) {
      setLog([`Error: ${err.message}`]); setBusy(false);
    }
  };
  useEffect(() => () => unsubRef.current?.(), []);

  // Delete one capture from the timeline. Destructive and not undoable, so it
  // routes through ConfirmDialog (never window.confirm) with the confirm button
  // styled destructive. The dialog names what actually goes and what stays,
  // because those differ: the PNG stays on disk (it can back other versions),
  // and any comments pinned to this version survive on the state, detached.
  const [pendingDelete, setPendingDelete] = useState(null);
  const [deleting, setDeleting] = useState(false);
  const confirmDeleteVersion = async () => {
    const v = pendingDelete;
    if (!v) return;
    setDeleting(true);
    try {
      await deleteUi2Version(v.versionId);
      // Selecting a version that no longer exists would leave the pane loading
      // a dead id, so drop back to current whenever the deleted one was shown.
      if (versionId === v.versionId) setVersionId(null);
      await loadDetail();
      bumpShots();
      setPendingDelete(null);
    } catch (err) {
      setLog([`Error: ${err.message}`]);
      setPendingDelete(null);
    } finally { setDeleting(false); }
  };

  // ── What the Data tab shows for the SELECTED version ──
  //
  // Two different things live here and must never be conflated:
  //   · the props THIS render was captured with (`vdata.props`, recorded on the
  //     version at capture time) — a record of what happened, and
  //   · the fixture on disk (`variant.fixtureProps`) — what the NEXT capture
  //     will use, which drifts the moment it is edited.
  // They are equal right after a capture and diverge as soon as you edit. So a
  // capture's own data is shown READ-ONLY, and editing is offered only when the
  // thing on screen is also the thing an edit would change: the current render,
  // still matching the fixture.
  // Per-prop closed value sets, from §4's Type column (`enumOptions`). Keyed by
  // the prop name a fixture writes — §4's ⊕ marker is annotation, not the name.
  // A prop the contract does not enumerate is absent here and keeps a free text
  // field; the fix for that is a `/ui2-component` re-run giving §4 a prop table,
  // never a guessed option list.
  const optionsByKey = useMemo(() => {
    const rows = detail?.contract?.propRows ?? [];
    return Object.fromEntries(rows.filter((p) => p.options?.length).map((p) => [p.key ?? p.name, p.options]));
  }, [detail?.contract?.propRows]);

  // Artwork for the option sets, keyed by prop — served from the PROVIDER row's
  // assets (C-021 for a glyph), so one inventory previews everywhere.
  const assetsByKey = useMemo(() => detail?.propAssets ?? null, [detail?.propAssets]);

  const dataView = useMemo(() => {
    const fixtureProps = activeVariant?.fixtureProps ?? null;
    if (!fixtureProps) return null;                       // state isn't in the fixture — SidePanel says so
    const currentId = activeVariant?.versions?.[0]?.versionId ?? null;
    const onCurrent = versionId === null || versionId === currentId;
    const captured = vdata?.props ?? null;
    // Key order can differ between a hand-edited fixture and a recorded capture,
    // so compare by sorted keys rather than raw JSON.
    const stable = (o) => JSON.stringify(o, Object.keys(o ?? {}).sort());
    const matchesFixture = !!captured && stable(captured) === stable(fixtureProps);

    if (captured) {
      if (onCurrent && matchesFixture) return { props: captured, optionsByKey, assetsByKey, editable: true, note: null, hint: null };
      return {
        props: captured,
        optionsByKey,
        assetsByKey,
        editable: false,
        hint: 'The data this render was captured with.',
        note: onCurrent
          ? 'The fixture has been edited since this capture, so this render no longer reflects it. Recapture to apply the current fixture data.'
          : 'Read-only: this is an older capture. Select the current render to edit the fixture data.',
      };
    }
    // No recorded props: the frozen Figma snapshot (never a capture), or a
    // capture taken before the runner recorded them. Show the fixture, clearly
    // labelled as the fixture rather than as this version's data.
    return {
      props: fixtureProps,
      optionsByKey,
      assetsByKey,
      editable: onCurrent,
      hint: 'Current fixture data — what the next capture will use.',
      note: 'This version recorded no data of its own (the frozen Figma snapshot is not a capture).',
    };
  }, [activeVariant, vdata, versionId, optionsByKey, assetsByKey]);

  // Data tab — write the edited props back to this state's fixture entry, then
  // reload so the Data tab reflects what is actually on disk. "Save & Recapture"
  // re-renders THIS state only (minutes per state), which is the whole point of
  // editing the data: see the new render beside the frozen snapshot.
  const saveFixture = async (props, { recapture = false } = {}) => {
    if (!detail?.id || !activeVariant) return;
    await saveUi2Fixture(detail.id, activeVariant.name, props);
    await loadDetail();
    if (recapture) await runCapture();
  };

  // A built component has an `iphone` render on the same version; before that
  // there is only the frozen snapshot, so the toggle has nothing to switch to.
  const platforms = detail?.built ? ['design', 'iphone'] : ['design'];

  // Keybindings: c = comment mode, Esc = cancel (same as 1.0).
  useEffect(() => {
    const onKey = (e) => {
      const el = e.target;
      const typing = el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.isContentEditable);
      if (e.key === 'Escape') { setCommentMode(false); setDraftPin(null); setSelectedCommentId(null); return; }
      if (typing) return;
      if ((e.key === 'c' || e.key === 'C') && canComment) { setCommentMode((m) => !m); setDraftPin(null); }
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [canComment]);

  // The comments panel's chat composer: a message about the variant as a whole, with no
  // pin. `x`/`y` are simply omitted — the server stores NULL, and CommentLayer skips it.
  const postMessage = async (text) => {
    if (!detail?.comparisonId || !text.trim()) return;
    await addComment(detail.comparisonId, {
      variantName: vdata?.variantName ?? activeVariant?.name ?? 'default',
      platform: activeShot.platform,
      viewport: detail?.viewport ?? 'design',
      text: text.trim(),
      source: 'user',
    });
    await refreshComments();
  };

  const commentApi = {
    // Scoped to the platform actually on screen (`activeShot.platform`, which
    // already accounts for a version-with-no-shot fallback). CommentsTab's
    // list AND its "N open" badge both derive from this one array, so
    // filtering here — rather than inside CommentsTab — keeps both
    // automatically in agreement without CommentsTab or SidePanel needing to
    // know about platforms at all. RenderPane is shared with the 1.0 era,
    // but ComponentsLayout.jsx assembles its OWN `commentApi.comments`
    // (hardcoding `platform: 'iphone'` on every 1.0 comment, confirmed at its
    // :215/:283) — this filter only ever runs on 2.0's array, so 1.0 is
    // untouched regardless of what this line does.
    comments: (vdata?.comments ?? []).filter((c) => c.platform === activeShot.platform),
    commentMode, setCommentMode,
    draftPin, placeDraft, submitDraft, cancelDraft: () => setDraftPin(null),
    selectedCommentId, setSelectedCommentId,
    canComment, onReply, onResolve, onDelete, postMessage,
  };

  // RenderPane keys its title off `name`; show the id with it. A screen's id IS
  // its handle (`study-program-home`) and its name is the prose title, so the two
  // read as a sentence rather than as the component form's "C-052 DayChip".
  const renderDetail = useMemo(
    () => (detail ? { ...detail, name: isScreen ? `${detail.id} — ${detail.name}` : `${detail.id} ${detail.name}` } : null),
    [detail, isScreen],
  );

  // Built components recapture the simulator render; unbuilt ones only have a
  // frozen snapshot to re-read. `recapture`/`busy`/`emptyAction` all describe
  // what `onRecapture` actually does when clicked, which is gated on
  // `detail?.built` alone (runCapture vs runRefresh) — never on which platform
  // happens to be toggled, so a built component's empty-state button says
  // "Capture now" even while the design side is showing.
  const renderLabels = useMemo(() => {
    // An undesigned state has no Figma artwork and nothing built. It gets no
    // capture button at all (`emptyAction: null`): capturing one would render a
    // design that does not exist and pre-empt the ruling its OQ is waiting on
    // (preview-build.md §3 rule 6). The consumption cell already names that OQ.
    if (activeVariant?.undesigned) {
      return {
        ...RENDER_LABELS,
        emptyAction: null,
        empty: `Undesigned state — no Figma artwork and nothing built${activeVariant.consumption ? ` (${activeVariant.consumption})` : ''}.`,
      };
    }
    // `allItemSub` counts the states the runner will actually visit — the ones
    // present in the fixture (`fixtureProps !== null`), not every §3 row, since
    // undesigned rows have no fixture entry and are never captured.
    const capturable = (detail?.variants ?? []).filter((v) => v.fixtureProps !== null).length;
    const base = detail?.built
      ? {
        ...RENDER_LABELS,
        recapture: 'Capture',
        busy: 'Capturing…',
        emptyAction: 'Capture now',
        variantItem: 'Capture this state',
        allItem: 'Capture all states',
        allItemSub: capturable ? `${capturable} state${capturable === 1 ? '' : 's'}` : 'whole component',
      }
      : RENDER_LABELS;
    // `current` describes what is actually ON SCREEN — the SHOWN platform
    // (`activeShot.platform`, post-fallback), not the raw toggle position. A
    // built component viewed before it has ever been captured still falls
    // back to the Figma snapshot (`activeShot.fallback`), so the label must
    // say so rather than claiming a built render that isn't there.
    return { ...base, current: activeShot.platform === 'iphone' ? 'Built render' : 'Frozen Figma snapshot' };
  }, [detail?.built, detail?.variants, activeShot.platform, activeVariant?.undesigned, activeVariant?.consumption]);

  // Prompt menu (RenderPane). 2.0 comments are resolved against the frozen Figma snapshot by
  // /ui2-resolve, which takes the registry id and an OPTIONAL state slug — so "this state" and
  // "every state" are the same command with and without the second argument.
  const prompts = useMemo(() => {
    if (!detail?.id) return [];
    // A screen has no /ui2-resolve equivalent — its comments are answered by
    // re-running the spec against the design, so the one prompt offered is the
    // spec command the server already composed (with the node URL when it has
    // one, so the string is runnable verbatim).
    if (isScreen) {
      return [{ label: 'Re-spec this screen', sub: detail.commands.spec, text: detail.commands.spec }];
    }
    const list = [];
    if (activeVariant?.slug) {
      list.push({
        label: 'Resolve variant comments',
        sub: `/ui2-resolve ${detail.id} ${activeVariant.slug}`,
        text: `/ui2-resolve ${detail.id} ${activeVariant.slug}`,
      });
    }
    list.push({
      label: 'Resolve all comments',
      sub: `/ui2-resolve ${detail.id}`,
      text: `/ui2-resolve ${detail.id}`,
    });
    return list;
  }, [detail?.id, detail?.commands?.spec, activeVariant?.slug, isScreen]);

  return (
    <div className="layout cmp-cb">
      <AppHeader>
        {busy && (
          <div className="layout__capture-group">
            <button className="layout__activity-btn" disabled><span className="layout__activity-spinner" />Refreshing…</button>
          </div>
        )}
      </AppHeader>

      <div className="cmp-cb__cols">
      {treeError
        ? <div className="cmp-cb-col cmp-cb-col--tree">{header}<div className="error-banner">{treeError}<button className="btn btn--mini" style={{ marginLeft: 8 }} onClick={loadTree}>Retry</button></div></div>
        : (
          <Ui2Tree
            header={header}
            data={treeData}
            screens={screenData}
            selectedId={id}
            onSelect={(row) => navigate(`/components/2.0/${row.id}`)}
          />
        )}

      <VariantList
        detail={detail}
        selectedVariant={activeVariant?.name}
        onSelect={(name) => {
          const v = detail?.variants?.find((x) => x.name === name);
          if (v) navigate(variantPath(v));
        }}
        mode="design"
        emptyLabel={isScreen ? 'no frames — screen not specced yet' : 'no states — component not specced yet'}
      />

      <RenderPane
        detail={renderDetail}
        detailError={detailError}
        variant={activeVariant}
        viewport={detail?.viewport ?? 'design'}
        onViewport={() => {}}
        versionId={versionId}
        onSelectVersion={setVersionId}
        vdata={vdata}
        shotsVersion={shotsVersion}
        capturing={busy}
        log={log}
        onRecapture={detail?.built ? runCapture : runRefresh}
        onDeleteVersion={detail?.canCapture ? setPendingDelete : null}
        commentApi={commentApi}
        platform={platform}
        platforms={platforms}
        onPlatform={setPlatform}
        activeShot={activeShot}
        allVariants={!!detail?.built}
        prompts={prompts}
        labels={renderLabels}
        emptyState={detail?.needsSpec ? <Ui2SpecChecklist detail={detail} /> : null}
        onHoverInspect={hoverInspect}
        onClearInspect={clearInspect}
        hoverBox={hoverTarget?.rect ?? null}
        inspectBox={inspectBox}
      />

      <SidePanel
        detail={detail}
        variant={activeVariant}
        activeVersionId={activeVersionId}
        currentVersionId={activeVariant?.versions?.[0]?.versionId ?? null}
        onSelectVersion={setVersionId}
        commentApi={commentApi}
        onSaveFixture={saveFixture}
        dataView={dataView}
        mode="design"
        elements={vdata?.elements ?? null}
        platform={activeShot.platform}
        onInspect={setInspectBox}
      />
      </div>

      <ConfirmDialog
        open={!!pendingDelete}
        title="Delete this capture?"
        confirmLabel="Delete capture"
        destructive
        busy={deleting}
        onConfirm={confirmDeleteVersion}
        onCancel={() => setPendingDelete(null)}
      >
        <div>
          The render captured on{' '}
          <strong>{pendingDelete ? new Date(pendingDelete.capturedAt).toLocaleString() : ''}</strong>{' '}
          is removed from this state&rsquo;s timeline permanently. This cannot be undone.
        </div>
        {pendingDelete?.unresolvedComments > 0 && (
          <div className="cmp-confirm__note">
            {pendingDelete.unresolvedComments} unresolved comment
            {pendingDelete.unresolvedComments === 1 ? '' : 's'} pinned here will stay on the state,
            no longer attached to a version.
          </div>
        )}
      </ConfirmDialog>
    </div>
  );
}
