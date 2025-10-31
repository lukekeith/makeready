/**
 * Combines multiple class names into a single string, filtering out falsy values
 *
 * @example
 * classnames('foo', 'bar') // 'foo bar'
 * classnames('foo', false && 'bar', 'baz') // 'foo baz'
 * classnames('foo', undefined, 'bar') // 'foo bar'
 */
export declare function classnames(...classes: (string | undefined | false | null)[]): string;
export default classnames;
