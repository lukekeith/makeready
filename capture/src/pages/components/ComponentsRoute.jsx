// /components/* — picks the era, then hands off to that era's host.
//
// The era is a route segment (`/components/1.0/…`, `/components/2.0/…`) rather
// than component state so links, bookmarks and the /component-resolve command
// are unambiguous about which universe they mean. A path without an era (an old
// link, or a bare /components) redirects to the last era used.
import React, { useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import ComponentsLayout from './ComponentsLayout.jsx';
import Ui2Layout from './Ui2Layout.jsx';
import EraSwitch, { ERAS } from './EraSwitch.jsx';

const ERA_KEY = 'capture-ui:components-era';
const isEra = (seg) => ERAS.some((e) => e.id === seg);

export default function ComponentsRoute() {
  const splat = useParams()['*'] ?? '';
  const navigate = useNavigate();
  const [first, ...rest] = splat.split('/').filter(Boolean);
  const era = isEra(first) ? first : null;

  useEffect(() => {
    if (era) { try { localStorage.setItem(ERA_KEY, era); } catch { /* ignore */ } return; }
    let last = '1.0';
    try { last = localStorage.getItem(ERA_KEY) ?? '1.0'; } catch { /* ignore */ }
    // A pre-era path keeps its target and lands in 1.0, which is where every
    // such link pointed (built Swift components).
    navigate(splat ? `/components/1.0/${splat}` : `/components/${isEra(last) ? last : '1.0'}`, { replace: true });
  }, [era, splat, navigate]);

  if (!era) return null;
  const sub = rest.join('/');
  const header = <EraSwitch era={era} />;
  return era === '2.0'
    ? <Ui2Layout sub={sub} header={header} />
    : <ComponentsLayout sub={sub} header={header} />;
}
