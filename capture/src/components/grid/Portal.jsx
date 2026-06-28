import { createPortal } from 'react-dom';
import React from 'react';

// Renders children into document.body (or a given container) once mounted.
// Ported from fai-cd packages/ui _internal/portal.
export function Portal({ children, container }) {
  const [mounted, setMounted] = React.useState(false);
  React.useEffect(() => { setMounted(true); }, []);
  if (!mounted) return null;
  return createPortal(children, container ?? document.body);
}
