import React, { useContext, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { CaptureContext } from '../App.jsx';
import CopyCode from '../components/CopyCode.jsx';

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

export default function SetDetail() {
  const { platform, folder } = useParams();
  const { manifest, capturesVersion } = useContext(CaptureContext);

  if (!manifest) return <div className="empty-state">Loading manifest...</div>;

  const set = manifest.sets.find((s) => s.folder === folder);
  if (!set) {
    return (
      <div className="empty-state">
        Set <code>{folder}</code> not found.
      </div>
    );
  }

  return (
    <>
      <div className="page-head">
        <div>
          <div className="page-head__crumbs">
            <Link to={`/${platform}`}>All sets</Link> / {set.title}
          </div>
          <h1 className="page-head__title">{set.title}</h1>
          <div className="page-head__subtitle">
            <CopyCode value={`capture/${folder}`} />
            {' \u00b7 '}
            {set.screens?.length ?? 0} screen{(set.screens?.length ?? 0) !== 1 ? 's' : ''}
          </div>
        </div>
      </div>

      <div className="screens-grid">
        {(set.screens ?? []).map((screen) => {
          const dims = manifest.viewportDimensions ?? {};
          const largest = (screen.viewports ?? []).reduce((best, vp) => {
            const w = dims[vp]?.width ?? 0;
            const bestW = dims[best]?.width ?? 0;
            return w > bestW ? vp : best;
          }, screen.viewports?.[0] ?? '');
          const src = largest
            ? `/screenshots/${platform}/${folder}/screenshots/${largest}/${screen.output}?v=${capturesVersion}`
            : null;
          return (
            <Link
              to={`/${platform}/screen/${folder}/${screen.screen}`}
              className="screen-card"
              key={screen.file}
            >
              <div className="screen-card__img-wrap">
                <ScreenImage src={src} alt={screen.title} />
              </div>
              <div className="screen-card__info">
                <div className="screen-card__title">{screen.title}</div>
                <div className="screen-card__meta">{screen.file}</div>
              </div>
            </Link>
          );
        })}
      </div>
    </>
  );
}
