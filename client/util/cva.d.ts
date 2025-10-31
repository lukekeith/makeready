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
export declare const cva: <T>(...args: Parameters<typeof cvaPackage<T>>) => any;
export type VariantProps<T extends (...args: any) => any> = CVAVariantProps<T>;
