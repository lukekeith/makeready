import { cva as cvaPackage, type VariantProps as CVAVariantProps } from "class-variance-authority";

/**
 * Custom CVA wrapper that provides type-safe enum-like access to variants
 *
 * @example
 * const ButtonCva = cva("Button", {
 *   variants: {
 *     variant: { Primary: "...", Secondary: "..." },
 *     size: { Small: "...", Large: "..." }
 *   },
 *   defaultVariants: { variant: "Primary", size: "Small" }
 * });
 *
 * // Access variants as enums
 * <Button variant={ButtonCva.variant.Primary} size={ButtonCva.size.Large} />
 *
 * // Access defaults
 * const variant = props.variant ?? ButtonCva.defaults?.variant;
 *
 * // Call CVA function
 * const classes = ButtonCva.variants({ variant, size });
 */
export const cva = <T>(...args: Parameters<typeof cvaPackage<T>>) => {
  const result = cvaPackage(...args);
  const variantOptions = args[1]?.variants;
  const defaults = args[1]?.defaultVariants;
  const enums = getEnums(variantOptions);

  return {
    variants: result,
    defaults,
    ...enums
  };
};

function getEnums(variantOptions: any) {
  const enums: any = {};
  if (!variantOptions) return enums;

  for (const key in variantOptions) {
    enums[key] = Object.keys(variantOptions[key]).reduce((acc, variant) => {
      acc[variant] = variant;
      return acc;
    }, {} as any);
  }

  return enums;
}

// Re-export the type (not a runtime export)
export type VariantProps<T extends (...args: any) => any> = CVAVariantProps<T>;
