import { useEffect, useState } from 'react';

/**
 * Hook to manage component lifecycle with MobX store
 * Calls willMount and willUnmount on the store if they exist
 *
 * @example
 * export const HomePage = observer(() => {
 *   const { store, shouldMount } = useLifecycle(Application.ui.home);
 *   if (!shouldMount) return null;
 *
 *   return <div>Content</div>;
 * });
 *
 * @param store - MobX store with optional willMount/willUnmount methods
 * @returns Object with store reference and shouldMount boolean
 */
export function useLifecycle<T extends Record<string, any>>(store: T) {
  const [shouldMount, setShouldMount] = useState(false);

  useEffect(() => {
    // Call willMount if it exists
    if (store && typeof store.willMount === 'function') {
      const result = store.willMount();
      // willMount can return false to prevent mounting
      setShouldMount(result !== false);
    } else {
      setShouldMount(true);
    }

    // Cleanup function calls willUnmount
    return () => {
      if (store && typeof store.willUnmount === 'function') {
        store.willUnmount();
      }
    };
  }, [store]);

  return { store, shouldMount };
}

export default useLifecycle;
