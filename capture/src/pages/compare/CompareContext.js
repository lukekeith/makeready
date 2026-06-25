import { createContext } from 'react';

/**
 * Shared state for the Compare section: the inventory manifest, a reload hook,
 * a bump counter for cache-busting screenshot URLs after a capture, and the
 * active capture run (so the layout can show progress while a detail view
 * triggered it).
 */
export const CompareContext = createContext(null);
