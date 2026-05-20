import React, { useContext, useEffect, useState } from 'react';
import { CaptureContext } from '../App.jsx';

/**
 * Renders a screenshot tile.
 *
 * Props:
 *   folder   — workflow folder name
 *   output   — PNG file name (e.g. "03-phone.png")
 *   viewport — viewport folder name (e.g. "iphone-14"); required
 *   caption  — optional override label (defaults to viewport)
 */
export default function Thumbnail({ folder, output, viewport, caption }) {
  const { capturesVersion } = useContext(CaptureContext);
  const [missing, setMissing] = useState(false);
  // Retry the <img> on every capture bump. Without this, a tile that 404'd
  // before the first capture would stay "not captured" forever — the latched
  // error state hides the <img> element so a new ?v= URL never gets loaded.
  useEffect(() => {
    setMissing(false);
  }, [capturesVersion]);
  const src = `/capture/${folder}/screenshots/${viewport}/${output}?v=${capturesVersion}`;

  return (
    <div className="thumb">
      {missing ? (
        <div className="thumb--missing">not captured</div>
      ) : (
        <img
          className="thumb__img"
          src={src}
          alt={`${folder} ${output} ${viewport}`}
          onError={() => setMissing(true)}
          loading="lazy"
        />
      )}
      <div className="thumb__caption">{caption ?? viewport}</div>
    </div>
  );
}
