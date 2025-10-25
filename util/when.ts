/**
 * Conditionally renders an element based on a boolean condition
 * Returns null if condition is false
 *
 * @example
 * return (
 *   <div>
 *     {when(isLoading, <Spinner />)}
 *     {when(hasError, <ErrorMessage />)}
 *   </div>
 * );
 *
 * @param condition - Boolean condition to evaluate
 * @param element - Element to render if condition is true
 * @returns The element if condition is true, null otherwise
 */
export function when<T>(condition: boolean, element: T): T | null {
  return condition ? element : null;
}

/**
 * Conditionally renders elements based on a boolean condition
 * Provides both true and false branches
 *
 * @example
 * return whenElse(
 *   isLoggedIn,
 *   <Dashboard />,
 *   <LoginForm />
 * );
 *
 * @param condition - Boolean condition to evaluate
 * @param trueElement - Element to render if condition is true
 * @param falseElement - Element to render if condition is false
 * @returns trueElement if condition is true, falseElement otherwise
 */
export function whenElse<T, F>(
  condition: boolean,
  trueElement: T,
  falseElement: F
): T | F {
  return condition ? trueElement : falseElement;
}

export default when;
