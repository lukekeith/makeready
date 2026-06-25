import React, { useContext } from 'react';
import { Link } from 'react-router-dom';
import { CaptureContext } from '../App.jsx';

export default function PlatformPicker() {
  const { platforms } = useContext(CaptureContext);

  if (!platforms.length) return <div className="empty-state">Loading...</div>;

  return (
    <div className="platform-picker">
      <h1 className="platform-picker__title">MakeReady Capture</h1>
      <div className="platform-picker__grid">
        {platforms.map((plat) => (
          <Link to={`/${plat.id}`} className="platform-card" key={plat.id}>
            <div className="platform-card__icon">
              {plat.id === 'iphone' ? (
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                  <rect x="5" y="2" width="14" height="20" rx="3" />
                  <line x1="12" y1="18" x2="12" y2="18.01" strokeWidth="2" />
                </svg>
              ) : (
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                  <rect x="2" y="3" width="20" height="14" rx="2" />
                  <line x1="8" y1="21" x2="16" y2="21" />
                  <line x1="12" y1="17" x2="12" y2="21" />
                </svg>
              )}
            </div>
            <div className="platform-card__title">{plat.title}</div>
          </Link>
        ))}
        <Link to="/compare" className="platform-card platform-card--compare">
          <div className="platform-card__icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
              <rect x="3" y="4" width="7" height="16" rx="1.5" />
              <rect x="14" y="4" width="7" height="16" rx="1.5" />
              <line x1="12" y1="2" x2="12" y2="22" strokeDasharray="2 2" />
            </svg>
          </div>
          <div className="platform-card__title">Compare</div>
          <div className="platform-card__sub">iPhone vs Web, same data</div>
        </Link>
      </div>
    </div>
  );
}
