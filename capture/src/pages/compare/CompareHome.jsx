import React, { useContext } from 'react';
import { Link } from 'react-router-dom';
import { CompareContext } from './CompareContext.js';

export default function CompareHome() {
  const { manifest } = useContext(CompareContext);
  const all = manifest?.types?.flatMap((t) => t.comparisons.filter((c) => !c.error)) ?? [];

  return (
    <div className="cmp-home">
      <div className="page-head">
        <h1 className="page-head__title">Compare</h1>
        <div className="page-head__subtitle">
          Apples-to-apples comparison of the iPhone app and the web client rendering the
          <strong> same data</strong> at the same viewport. Pick a screen or component from the left,
          choose a viewport, and capture both sides.
        </div>
      </div>
      <div className="cmp-home__grid">
        {all.map((c) => (
          <Link key={c.id} to={`/compare/${c.id}`} className="cmp-home__card">
            <div className="cmp-home__card-type">{c.type}</div>
            <div className="cmp-home__card-title">{c.title}</div>
            <div className="cmp-home__card-group">{c.group}</div>
          </Link>
        ))}
        {all.length === 0 && <div className="empty-state">No comparisons defined yet.</div>}
      </div>
    </div>
  );
}
