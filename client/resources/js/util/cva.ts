import {
  cva as cvaPackage,
  type VariantProps as CVAVariantProps,
} from 'class-variance-authority'
import type { ClassValue } from 'clsx'

/**
 * Custom CVA wrapper that provides type-safe enum-like access to variants.
 * Direct port from archive/react-spa:util/cva.ts — same API, same behavior.
 *
 * @example
 * const ButtonCva = cva("Button", {
 *   variants: {
 *     variant: { Primary: "Button--primary", Secondary: "Button--secondary" },
 *     size: { Default: "Button--size-default" }
 *   },
 *   defaultVariants: { variant: "Primary", size: "Default" }
 * });
 *
 * // Enum-like access
 * ButtonCva.variant.Primary  // => "Primary"
 *
 * // Access defaults
 * ButtonCva.defaults?.variant  // => "Primary"
 *
 * // Generate class string
 * ButtonCva.variants({ variant: 'Primary', size: 'Default' })
 */
export function cva<
  V extends Record<string, Record<string, ClassValue>>
>(
  base: ClassValue,
  config: {
    variants: V
    defaultVariants?: { [K in keyof V]?: keyof V[K] }
    compoundVariants?: Array<
      { [K in keyof V]?: keyof V[K] } & { class?: ClassValue; className?: ClassValue }
    >
  }
): {
  variants: (
    props?: { [K in keyof V]?: keyof V[K] | null } & { class?: ClassValue; className?: ClassValue }
  ) => string
  defaults: { [K in keyof V]?: keyof V[K] } | undefined
} & { [K in keyof V]: { [VK in keyof V[K]]: VK } } {
  // Call the real cva to get the variants function
  const variantsFunc = cvaPackage(base, config as unknown as Parameters<typeof cvaPackage>[1])

  // Build the enum-like objects for each variant group
  const enums: Record<string, Record<string, string>> = {}
  for (const variantKey in config.variants) {
    enums[variantKey] = {}
    for (const valueName in config.variants[variantKey]) {
      enums[variantKey][valueName] = valueName
    }
  }

  // Combine the variants function, defaults, and enum accessors
  return {
    variants: variantsFunc,
    defaults: config.defaultVariants,
    ...enums,
  } as {
    variants: (
      props?: { [K in keyof V]?: keyof V[K] | null } & { class?: ClassValue; className?: ClassValue }
    ) => string
    defaults: { [K in keyof V]?: keyof V[K] } | undefined
  } & { [K in keyof V]: { [VK in keyof V[K]]: VK } }
}

// Re-export the type for use with CVA functions
export type VariantProps<T extends (...args: never[]) => unknown> = CVAVariantProps<T>
