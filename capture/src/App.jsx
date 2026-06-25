import React, { createContext, useCallback, useEffect, useMemo, useState } from 'react';
import { Routes, Route } from 'react-router-dom';
import Layout from './components/Layout.jsx';
import PlatformPicker from './pages/PlatformPicker.jsx';
import SetsIndex from './pages/SetsIndex.jsx';
import SetDetail from './pages/SetDetail.jsx';
import ScreenDetail from './pages/ScreenDetail.jsx';
import Preview from './pages/Preview.jsx';
import CompareLayout from './pages/compare/CompareLayout.jsx';
import CompareHome from './pages/compare/CompareHome.jsx';
import CompareDetail from './pages/compare/CompareDetail.jsx';
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
    }),
    [platforms, canCapture, currentPlatform, manifest, manifestError, reloadManifest, capturesVersion, bumpCapturesVersion, activeRun, drawerVisible],
  );

  return (
    <CaptureContext.Provider value={ctx}>
      <Routes>
        <Route path="/" element={<PlatformPicker />} />
        <Route path="/compare" element={<CompareLayout />}>
          <Route index element={<CompareHome />} />
          <Route path=":id" element={<CompareDetail />} />
          <Route path=":id/:version" element={<CompareDetail />} />
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
