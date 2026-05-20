<?php

namespace Tests\Feature;

use Tests\TestCase;

class CvaHelperTest extends TestCase
{
    /** @test */
    public function it_returns_base_class_when_no_variants_selected(): void
    {
        $result = cva('Button', [], []);
        $this->assertEquals('Button', $result);
    }

    /** @test */
    public function it_returns_base_class_with_empty_config(): void
    {
        $result = cva('Button', []);
        $this->assertEquals('Button', $result);
    }

    /** @test */
    public function it_maps_single_variant_to_bem_class(): void
    {
        $result = cva('Button', [
            'variants' => [
                'variant' => [
                    'Primary'   => 'Button--primary',
                    'Secondary' => 'Button--secondary',
                ],
            ],
        ], ['variant' => 'Primary']);

        $this->assertEquals('Button Button--primary', $result);
    }

    /** @test */
    public function it_maps_multiple_variants_combined(): void
    {
        $result = cva('Button', [
            'variants' => [
                'variant' => [
                    'Primary'   => 'Button--primary',
                    'Secondary' => 'Button--secondary',
                ],
                'size' => [
                    'Default' => 'Button--size-default',
                    'Sm'      => 'Button--size-sm',
                    'Lg'      => 'Button--size-lg',
                ],
                'mode' => [
                    'Action' => 'Button--mode-action',
                    'Block'  => 'Button--mode-block',
                ],
            ],
        ], [
            'variant' => 'Primary',
            'size'    => 'Lg',
            'mode'    => 'Block',
        ]);

        $this->assertEquals('Button Button--primary Button--size-lg Button--mode-block', $result);
    }

    /** @test */
    public function it_uses_default_variants_when_no_selection_provided(): void
    {
        $result = cva('Badge', [
            'variants' => [
                'variant' => [
                    'Default'     => 'Badge--default',
                    'Secondary'   => 'Badge--secondary',
                    'Destructive' => 'Badge--destructive',
                    'Outline'     => 'Badge--outline',
                ],
            ],
            'defaultVariants' => [
                'variant' => 'Default',
            ],
        ]);

        $this->assertEquals('Badge Badge--default', $result);
    }

    /** @test */
    public function it_returns_base_class_only_for_unknown_variant_value(): void
    {
        $result = cva('Button', [
            'variants' => [
                'variant' => [
                    'Primary'   => 'Button--primary',
                    'Secondary' => 'Button--secondary',
                ],
            ],
        ], ['variant' => 'NonExistentVariant']);

        $this->assertEquals('Button', $result);
    }

    /** @test */
    public function it_does_not_crash_on_unknown_variant_key(): void
    {
        $result = cva('Button', [
            'variants' => [
                'variant' => [
                    'Primary' => 'Button--primary',
                ],
            ],
        ], ['unknownKey' => 'SomeValue', 'variant' => 'Primary']);

        $this->assertEquals('Button Button--primary', $result);
    }

    /** @test */
    public function it_selected_variant_overrides_default_variant(): void
    {
        $result = cva('Badge', [
            'variants' => [
                'variant' => [
                    'Default'   => 'Badge--default',
                    'Secondary' => 'Badge--secondary',
                ],
            ],
            'defaultVariants' => [
                'variant' => 'Default',
            ],
        ], ['variant' => 'Secondary']);

        $this->assertEquals('Badge Badge--secondary', $result);
    }

    /** @test */
    public function it_skips_empty_string_variant_class(): void
    {
        $result = cva('Icon', [
            'variants' => [
                'size' => [
                    'Default' => '',
                    'Sm'      => 'Icon--sm',
                    'Lg'      => 'Icon--lg',
                ],
            ],
        ], ['size' => 'Default']);

        $this->assertEquals('Icon', $result);
    }
}
