import React, { useState } from 'react';

export default function CopyCode({ value, children, title, className = '' }) {
  const [copied, setCopied] = useState(false);

  const copy = async (e) => {
    e.preventDefault();
    e.stopPropagation();
    try {
      await navigator.clipboard.writeText(value);
      setCopied(true);
      setTimeout(() => setCopied(false), 1200);
    } catch {
      // Clipboard API blocked; ignore.
    }
  };

  return (
    <code
      className={`copy-code${copied ? ' copy-code--copied' : ''} ${className}`.trim()}
      title={title ?? `Click to copy: ${value}`}
      onClick={copy}
      role="button"
      tabIndex={0}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') copy(e);
      }}
    >
      {children ?? value}
      <span className="copy-code__flash" aria-hidden="true">
        {copied ? 'copied' : 'copy'}
      </span>
    </code>
  );
}
