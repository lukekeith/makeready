/**
 * Helper utilities for handling Express 5 route parameters.
 * In Express 5 types, req.params values can be string | string[].
 * These utilities safely extract string values.
 */

/**
 * Safely extract a string parameter from req.params.
 * Returns the first element if it's an array, or the string directly.
 * Returns undefined if the value is undefined.
 */
export function getParam(value: string | string[] | undefined): string | undefined {
  if (value === undefined) return undefined
  if (Array.isArray(value)) return value[0]
  return value
}

/**
 * Safely extract a required string parameter from req.params.
 * Throws an error if the value is undefined.
 */
export function requireParam(value: string | string[] | undefined, paramName: string): string {
  const result = getParam(value)
  if (result === undefined) {
    throw new Error(`Missing required parameter: ${paramName}`)
  }
  return result
}
