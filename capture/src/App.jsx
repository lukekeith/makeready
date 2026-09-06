import React, { createContext, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Routes, Route } from 'react-router-dom';
import { io } from 'socket.io-client';
import Layout from './components/Layout.jsx';
import PlatformPicker from './pages/PlatformPicker.jsx';
import SetsIndex from './pages/SetsIndex.jsx';
import SetDetail from './pages/SetDetail.jsx';
import ScreenDetail from './pages/ScreenDetail.jsx';
import Preview from './pages/Preview.jsx';
import CompareLayout from './pages/compare/CompareLayout.jsx';
import CompareHome from './pages/compare/CompareHome.jsx';
import CompareDetail from './pages/compare/CompareDetail.jsx';
import ComponentsRoute from './pages/components/ComponentsRoute.jsx';
import { fetchManifest, fetchPlatforms } from './api.js';

export const CaptureContext = createContext(null);

export default function App() {
  const [platforms, setPlatforms] = useState([]);
  const [canCapture, setCanCapture] = useState(false);
  const [manifest, setManifest] = useState(null);
  const [manifestError, setManifestError] = useState(null);
  const [capturesVersion, setCapturesVersion] = useState(() => Date.now());
  const [activeRun, setActiveRun] = useState(null);
  const [currentPlatform, setCurrentPlatform] = useState(null);
  const [drawerVisible, setDrawerVisible] = useState(false);
  const [liveConnected, setLiveConnected] = useState(false);

  // Load platforms list on mount
  useEffect(() => {
    fetchPlatforms()
      .then((data) => {
        setPlatforms(data.platforms ?? []);
        setCanCapture(data.canCapture ?? false);
      })
      .catch(() => setPlatforms([]));
  }, []);

  const reloadManifest = useCallback(async (platform) => {
    if (!platform) return;
    try {
      setManifest(await fetchManifest(platform));
      setManifestError(null);
    } catch (err) {
      setManifestError(err.message);
    }
  }, []);

  // Reload manifest when platform changes
  useEffect(() => {
    if (currentPlatform) {
      reloadManifest(currentPlatform);
    }
  }, [currentPlatform, reloadManifest]);

  // ── Realtime, once for the whole app ──
  // The server pushes an event whenever ANY capture writes a screenshot or a job
  // finishes — including captures run outside this UI (CLI, curl, an agent). One
  // socket lives here so every UI (platform sets, /compare, /components) shares
  // the same connection and the same `liveConnected` truth in the header, instead
  // of each layout opening its own. Consumers subscribe for the refresh; bursts
  // (e.g. a batch capture) are debounced here.
  const liveListeners = useRef(new Set());
  const subscribeLive = useCallback((fn) => {
    liveListeners.current.add(fn);
    return () => liveListeners.current.delete(fn);
  }, []);

  useEffect(() => {
    const socket = io({ path: '/socket.io', transports: ['websocket', 'polling'] });
    let timer = null;
    const fire = (event) => {
      clearTimeout(timer);
      timer = setTimeout(() => { for (const fn of liveListeners.current) fn(event); }, 300);
    };
    socket.on('connect', () => {
      setLiveConnected(true);
      // Refresh on (re)connect too: after a server restart — e.g. a new adapter
      // for a freshly-built Vue twin — the UI picks up the change immediately.
      fire('connect');
    });
    socket.on('disconnect', () => setLiveConnected(false));
    socket.on('compare:shot', () => fire('shot'));
    socket.on('compare:done', () => fire('done'));
    socket.on('compare:adapters', () => fire('adapters'));
    return () => { clearTimeout(timer); socket.close(); };
  }, []);

  const bumpCapturesVersion = useCallback(() => {
    setCapturesVersion(Date.now());
    reloadManifest(currentPlatform);
  }, [reloadManifest, currentPlatform]);

  const ctx = useMemo(
    () => ({
      platforms,
      canCapture,
      currentPlatform,
      setCurrentPlatform,
      manifest,
      manifestError,
      reloadManifest,
      capturesVersion,
      bumpCapturesVersion,
      activeRun,
      setActiveRun,
      drawerVisible,
      setDrawerVisible,
      liveConnected,
      subscribeLive,
    }),
    [platforms, canCapture, currentPlatform, manifest, manifestError, reloadManifest, capturesVersion, bumpCapturesVersion, activeRun, drawerVisible, liveConnected, subscribeLive],
  );

  return (
    <CaptureContext.Provider value={ctx}>
      <Routes>
        <Route path="/" element={<PlatformPicker />} />
        <Route path="/components/*" element={<ComponentsRoute />} />
        <Route path="/compare" element={<CompareLayout />}>
          <Route index element={<CompareHome />} />
          <Route path=":id" element={<CompareDetail />} />
          <Route path=":id/:variant" element={<CompareDetail />} />
        </Route>
        <Route path="/:platform" element={<Layout />}>
          <Route index element={<SetsIndex />} />
          <Route path="set/:folder" element={<SetDetail />} />
          <Route path="screen/:folder/:screen" element={<ScreenDetail />} />
        </Route>
        {/* Standalone preview (no layout) — opened in a new tab by the Code
            icon on each viewport thumbnail in ScreenDetail. */}
        <Route path="/:platform/preview/:folder/:screen/:size" element={<Preview />} />
      </Routes>
    </CaptureContext.Provider>
  );
}
