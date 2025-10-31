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
export declare function useLifecycle<T extends Record<string, any>>(store: T): {
    store: T;
    shouldMount: boolean;
};
export default useLifecycle;
