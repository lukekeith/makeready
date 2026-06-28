import { useState } from 'react';

// Browse-grid tile for one comparison, modeled on fai-cd's <CardDocument>: a
// fixed-height thumbnail (the iPhone screenshot only) with an info panel below
// carrying the title and metadata (type/group, variant count, render sites).
export function ComponentCard({
  title,
  type,
  group,
  thumbnailUrl,
  variantCount = 0,
  renderSites,
  onClick,
}) {
  // Fall back to the placeholder if the thumbnail fails to load. Keyed on the
  // URL so a recycled card re-attempts when it receives a different thumbnail.
  const [failedUrl, setFailedUrl] = useState(null);
  const showThumbnail = thumbnailUrl != null && failedUrl !== thumbnailUrl;

  return (
    <div
      className="ComponentCard"
      role="button"
      tabIndex={0}
      onClick={onClick}
      onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); onClick?.(); } }}
    >
      <div className="ComponentCard__Thumbnail">
        {showThumbnail ? (
          <img
            src={thumbnailUrl}
            alt={title}
            className="ComponentCard__Image"
            loading="lazy"
            onError={() => setFailedUrl(thumbnailUrl)}
          />
        ) : (
          <div className="ComponentCard__Placeholder">
            <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
              <rect x="5" y="2" width="14" height="20" rx="2.5" /><line x1="10" y1="19" x2="14" y2="19" />
            </svg>
            <span className="ComponentCard__PlaceholderLabel">not captured</span>
          </div>
        )}
        {type && <span className="ComponentCard__TypeChip">{type}</span>}
      </div>

      <div className="ComponentCard__Info">
        <div className="ComponentCard__Title" title={title}>{title}</div>
        <div className="ComponentCard__Meta">
          {group && <span className="ComponentCard__Group">{group}</span>}
          <span className="ComponentCard__MetaItem">{variantCount} variant{variantCount === 1 ? '' : 's'}</span>
          {renderSites != null && (
            <>
              <span className="ComponentCard__MetaDot" aria-hidden="true" />
              <span className="ComponentCard__MetaItem" title="Render sites — times this component is used in the iOS app">
                {renderSites} use{renderSites === 1 ? '' : 's'}
              </span>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
