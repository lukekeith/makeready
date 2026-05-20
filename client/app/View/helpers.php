<?php

// app/View/helpers.php
// Autoloaded via composer.json "autoload" > "files"

if (!function_exists('cva')) {
    /**
     * Class Variance Authority — PHP port for Blade components
     *
     * Maps variant key/value pairs to BEM CSS class strings.
     * Mirrors the TypeScript CVA API used in the Vue component layer.
     *
     * @param string $base      Base BEM block class (e.g. 'Button')
     * @param array  $config    {
     *     variants: array<string, array<string, string>>,
     *     defaultVariants?: array<string, string>
     * }
     * @param array  $selected  Variant key => value pairs from @props
     * @return string           Space-separated CSS class string
     *
     * @example
     *   cva('Button', ['variants' => ['variant' => ['Primary' => 'Button--primary']]], ['variant' => 'Primary'])
     *   // returns: "Button Button--primary"
     */
    function cva(string $base, array $config, array $selected = []): string
    {
        $classes = [$base];
        $variants = $config['variants'] ?? [];
        $defaults = $config['defaultVariants'] ?? [];

        foreach ($variants as $key => $map) {
            $value = $selected[$key] ?? ($defaults[$key] ?? null);
            if ($value !== null && isset($map[$value]) && $map[$value] !== '') {
                $classes[] = $map[$value];
            }
        }

        return implode(' ', array_filter($classes));
    }
}

if (!function_exists('format_phone')) {
    /**
     * Format a phone number for display: +12148623686 → (214) 862-3686
     */
    function format_phone(?string $phone): string
    {
        if (!$phone) return '';
        $digits = preg_replace('/\D/', '', $phone);
        // Strip leading country code (1 for US)
        if (strlen($digits) === 11 && $digits[0] === '1') {
            $digits = substr($digits, 1);
        }
        if (strlen($digits) === 10) {
            return '(' . substr($digits, 0, 3) . ') ' . substr($digits, 3, 3) . '-' . substr($digits, 6);
        }
        return $phone; // Return as-is if not a 10-digit US number
    }
}
