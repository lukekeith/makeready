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
import {
  fetchUi2Tree,
  fetchUi2Detail,
  fetchUi2Version,
  refreshUi2Snapshot,
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

/** `<C-###>[/<variant-slug>]`. The slug is the canonical key (lowercase, dashed,
 *  never percent-encoded), but links made before slugs existed carry the state's
 *  display name — which could hold slashes — so everything after the id is kept
 *  as one string and resolved against slug first, name second. */
function parseSub(sub) {
  const segs = (sub ?? '').split('/').filter(Boolean).map(decodeURIComponent);
  if (!segs.length || !ID_RE.test(segs[0])) return { id: null, key: null };
  return { id: segs[0].toUpperCase(), key: segs.slice(1).join('/') || null };
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

  const { id, key } = useMemo(() => parseSub(sub), [sub]);
  const variantPath = useCallback((v) => `/components/2.0/${id}/${v.slug}`, [id]);

  const loadTree = useCallback(async () => {
    try { setTreeData(await fetchUi2Tree()); setTreeError(null); }
    catch (err) { setTreeError(err.message); }
  }, []);
  useEffect(() => { loadTree(); }, [loadTree]);

  const loadDetail = useCallback(async () => {
    if (!id) { setDetail(null); setDetailError(null); return; }
    try { setDetail(await fetchUi2Detail(id)); setDetailError(null); }
    catch (err) { setDetail(null); setDetailError(err.message); }
  }, [id]);
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
  useEffect(() => { setPlatform('design'); }, [id]);

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

  // No web twin exists for a 2.0 component, so there is nothing to hit-test:
  // pins carry their fraction only (element targeting arrives with the build).
  // `platform` here is whatever RenderPane's ZoomPane is actually displaying
  // (the SHOWN platform, post-fallback) — not necessarily the toggle's raw
  // selection — so the pin is tagged with the image it was actually placed on.
  const placeDraft = (platform, viewport, x, y) => {
    setSelectedCommentId(null);
    setDraftPin({ platform, viewport, x, y });
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
      });
      setDraftPin(null); setCommentMode(false);
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
  // only the frozen snapshot to re-read.
  const runCapture = async () => {
    if (busy || !detail?.built || !activeVariant) return;
    setBusy(true); setLog([]);
    try {
      const { runId } = await captureUi2(detail.id, activeVariant.slug);
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
    canComment, onReply, onResolve, onDelete,
  };

  // RenderPane keys its title off `name`; show the registry id with it.
  const renderDetail = useMemo(
    () => (detail ? { ...detail, name: `${detail.id} ${detail.name}` } : null),
    [detail],
  );

  // Built components recapture the simulator render; unbuilt ones only have a
  // frozen snapshot to re-read. `recapture`/`busy`/`emptyAction` all describe
  // what `onRecapture` actually does when clicked, which is gated on
  // `detail?.built` alone (runCapture vs runRefresh) — never on which platform
  // happens to be toggled, so a built component's empty-state button says
  // "Capture now" even while the design side is showing.
  const renderLabels = useMemo(() => {
    const base = detail?.built
      ? { ...RENDER_LABELS, recapture: 'Recapture render', busy: 'Capturing…', emptyAction: 'Capture now' }
      : RENDER_LABELS;
    // `current` describes what is actually ON SCREEN — the SHOWN platform
    // (`activeShot.platform`, post-fallback), not the raw toggle position. A
    // built component viewed before it has ever been captured still falls
    // back to the Figma snapshot (`activeShot.fallback`), so the label must
    // say so rather than claiming a built render that isn't there.
    return { ...base, current: activeShot.platform === 'iphone' ? 'Built render' : 'Frozen Figma snapshot' };
  }, [detail?.built, activeShot.platform]);

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
        : <Ui2Tree header={header} data={treeData} selectedId={id} onSelect={(row) => navigate(`/components/2.0/${row.id}`)} />}

      <VariantList
        detail={detail}
        selectedVariant={activeVariant?.name}
        onSelect={(name) => {
          const v = detail?.variants?.find((x) => x.name === name);
          if (v) navigate(variantPath(v));
        }}
        mode="design"
        emptyLabel="no states — component not specced yet"
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
        commentApi={commentApi}
        platform={platform}
        platforms={platforms}
        onPlatform={setPlatform}
        activeShot={activeShot}
        allVariants={false}
        labels={renderLabels}
        emptyState={detail?.needsSpec ? <Ui2SpecChecklist detail={detail} /> : null}
        hoverBox={null}
      />

      <SidePanel
        detail={detail}
        variant={activeVariant}
        activeVersionId={activeVersionId}
        currentVersionId={activeVariant?.versions?.[0]?.versionId ?? null}
        onSelectVersion={setVersionId}
        commentApi={commentApi}
        mode="design"
      />
      </div>
    </div>
  );
}
