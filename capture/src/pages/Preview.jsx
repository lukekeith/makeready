import React, { useContext, useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { CaptureContext } from '../App.jsx';

const LARAVEL_BASE_URL =
  import.meta.env?.VITE_LARAVEL_BASE_URL ?? 'http://localhost:8000';

/**
 * Fixed-size device-preview frame. Opened in a new tab via the Code icon on
 * each viewport thumbnail: /:platform/preview/:folder/:screen/:size?viewport=name.
 * `:size` is `WIDTHxHEIGHT` (e.g. 440x956). The iframe is centered and
 * locked to those dimensions, so resizing the outer browser window pans the
 * backdrop without changing the emulated viewport inside.
 *
 * Clicking the viewport label in the top pill opens a menu of every viewport
 * preset from the manifest — picking one navigates to the same screen at
 * that viewport's dimensions, no re-open needed.
 */
export default function Preview() {
  const { platform, folder, screen, size } = useParams();
  const [searchParams] = useSearchParams();
  const viewportName = searchParams.get('viewport') ?? null;
  const navigate = useNavigate();

  const { manifest, reloadManifest, setCurrentPlatform } = useContext(CaptureContext);

  const [menuOpen, setMenuOpen] = useState(false);
  const switcherRef = useRef(null);

  // Ensure manifest is loaded for this platform
  useEffect(() => {
    setCurrentPlatform(platform);
  }, [platform, setCurrentPlatform]);

  const dimensions = manifest?.viewportDimensions ?? {};

  // Close the menu on outside-click or Escape.
  useEffect(() => {
    if (!menuOpen) return;
    const onClick = (e) => {
      if (switcherRef.current && !switcherRef.current.contains(e.target)) {
        setMenuOpen(false);
      }
    };
    const onKey = (e) => {
      if (e.key === 'Escape') setMenuOpen(false);
    };
    document.addEventListener('mousedown', onClick);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onClick);
      document.removeEventListener('keydown', onKey);
    };
  }, [menuOpen]);

  const [width, height] = (size ?? '').split('x').map((n) => parseInt(n, 10));
  const valid = Number.isFinite(width) && Number.isFinite(height) && width > 0 && height > 0;
  const src = `${LARAVEL_BASE_URL}/_capture/${encodeURIComponent(folder)}/${encodeURIComponent(screen)}`;

  // Sort viewports by width asc.
  const sortedViewports = useMemo(() => {
    return Object.entries(dimensions)
      .sort(([, a], [, b]) => {
        if (a.width !== b.width) return a.width - b.width;
        return a.height - b.height;
      });
  }, [dimensions]);

  const selectViewport = (name, d) => {
    setMenuOpen(false);
    navigate(
      `/${platform}/preview/${encodeURIComponent(folder)}/${encodeURIComponent(screen)}/${d.width}x${d.height}?viewport=${encodeURIComponent(name)}`,
      { replace: true },
    );
  };

  return (
    <div className="preview-page">
      <div className="preview-page__meta">
        <span className="preview-page__path">
          {folder} / {screen}
        </span>
        {valid && (
          <div className="preview-page__switcher" ref={switcherRef}>
            <button
              type="button"
              className="preview-page__dims"
              onClick={() => setMenuOpen((o) => !o)}
              aria-haspopup="listbox"
              aria-expanded={menuOpen}
              title="Switch viewport"
            >
              {viewportName ? `${viewportName} \u00b7 ` : ''}{width}\u00d7{height} \u25be
            </button>
            {menuOpen && sortedViewports.length > 0 && (
              <ul className="preview-page__menu" role="listbox">
                {sortedViewports.map(([name, d]) => {
                  const active = name === viewportName;
                  return (
                    <li key={name}>
                      <button
                        type="button"
                        role="option"
                        aria-selected={active}
                        className={`preview-page__menu-item${active ? ' preview-page__menu-item--active' : ''}`}
                        onClick={() => selectViewport(name, d)}
                      >
                        <span className="preview-page__menu-name">{name}</span>
                        <span className="preview-page__menu-dims">{d.width}\u00d7{d.height}</span>
                      </button>
                    </li>
                  );
                })}
              </ul>
            )}
          </div>
        )}
        <a
          className="preview-page__raw"
          href={src}
          target="_blank"
          rel="noreferrer"
        >
          open raw \u2197
        </a>
      </div>
      {valid ? (
        <iframe
          className="preview-page__frame"
          title={`${folder}/${screen} preview`}
          src={src}
          style={{ width: `${width}px`, height: `${height}px` }}
        />
      ) : (
        <div className="preview-page__error">
          Invalid viewport size. Expected format <code>WIDTHxHEIGHT</code>.
        </div>
      )}
    </div>
  );
}
