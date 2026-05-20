import React, { useContext, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { CaptureContext } from '../App.jsx';

function ScreenImage({ src, alt }) {
  const [failed, setFailed] = useState(false);
  if (!src || failed) {
    return <div className="screen-card__img--missing">not captured</div>;
  }
  return (
    <img
      className="screen-card__img"
      src={src}
      alt={alt}
      loading="lazy"
      onError={() => setFailed(true)}
    />
  );
}

export default function SetsIndex() {
  const { platform } = useParams();
  const { manifest, capturesVersion } = useContext(CaptureContext);

  if (!manifest) return <div className="empty-state">Loading manifest...</div>;

  // Flatten all screens across all sets, pick the largest viewport for each
  const allScreens = [];
  for (const set of manifest.sets) {
    for (const screen of set.screens ?? []) {
      // Pick largest viewport by width
      const dims = manifest.viewportDimensions ?? {};
      const largest = (screen.viewports ?? []).reduce((best, vp) => {
        const w = dims[vp]?.width ?? 0;
        const bestW = dims[best]?.width ?? 0;
        return w > bestW ? vp : best;
      }, screen.viewports?.[0] ?? '');

      allScreens.push({ set, screen, viewport: largest });
    }
  }

  return (
    <div className="screens-grid">
      {allScreens.map(({ set, screen, viewport }) => {
        const src = viewport
          ? `/screenshots/${platform}/${set.folder}/screenshots/${viewport}/${screen.output}?v=${capturesVersion}`
          : null;
        return (
          <Link
            to={`/${platform}/screen/${set.folder}/${screen.screen}`}
            className="screen-card"
            key={`${set.folder}/${screen.screen}`}
          >
            <div className="screen-card__img-wrap">
              <ScreenImage src={src} alt={screen.title} />
            </div>
            <div className="screen-card__info">
              <div className="screen-card__title">{screen.title}</div>
              <div className="screen-card__meta">{set.title}</div>
            </div>
          </Link>
        );
      })}
    </div>
  );
}
