/**
 * Convert a Laravel Blade view identifier (dot-notated) into the source
 * file path relative to the client repo.
 *
 * Example: "pages.join-group" → "resources/views/pages/join-group.blade.php"
 */
export function viewToBladePath(view) {
  if (!view || typeof view !== 'string') return null;
  return `resources/views/${view.split('.').join('/')}.blade.php`;
}
