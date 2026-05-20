@props([
    'variant'     => 'Primary',
    'size'        => 'Default',
    'mode'        => 'Action',
    'loading'     => false,
    'disabled'    => false,
    'type'        => 'button',
    'label'       => null,
    'description' => null,
])

@php
    $isJump = in_array($variant, ['Jump', 'JumpPrimary']);

    if ($isJump) {
        $classes = cva('Button', [
            'variants' => [
                'variant' => [
                    'Primary'     => 'Button--primary',
                    'Secondary'   => 'Button--secondary',
                    'Destructive' => 'Button--destructive',
                    'Outline'     => 'Button--outline',
                    'Ghost'       => 'Button--ghost',
                    'Link'        => 'Button--link',
                    'LinkMuted'   => 'Button--link-muted',
                    'White'       => 'Button--white',
                    'Jump'        => 'Button--jump',
                    'JumpPrimary' => 'Button--jump-primary',
                ],
            ],
            'defaultVariants' => ['variant' => 'Primary'],
        ], ['variant' => $variant]);
    } else {
        $classes = cva('Button', [
            'variants' => [
                'variant' => [
                    'Primary'     => 'Button--primary',
                    'Secondary'   => 'Button--secondary',
                    'Destructive' => 'Button--destructive',
                    'Outline'     => 'Button--outline',
                    'Ghost'       => 'Button--ghost',
                    'Link'        => 'Button--link',
                    'LinkMuted'   => 'Button--link-muted',
                    'White'       => 'Button--white',
                    'Jump'        => 'Button--jump',
                    'JumpPrimary' => 'Button--jump-primary',
                ],
                'size' => [
                    'Default' => 'Button--size-default',
                    'Sm'      => 'Button--size-sm',
                    'Lg'      => 'Button--size-lg',
                    'Icon'    => 'Button--size-icon',
                ],
                'mode' => [
                    'Action' => 'Button--mode-action',
                    'Block'  => 'Button--mode-block',
                ],
            ],
            'defaultVariants' => [
                'variant' => 'Primary',
                'size'    => 'Default',
                'mode'    => 'Action',
            ],
        ], ['variant' => $variant, 'size' => $size, 'mode' => $mode]);
    }

    if ($loading) {
        $classes .= ' Button--loading';
    }
@endphp

<button
    type="{{ $type }}"
    {{ $attributes->merge(['class' => $classes]) }}
    @if($disabled || $loading) disabled @endif
>
    <span class="Button__content">
        @if($isJump)
            <span class="Button__details">
                @if($label)<span class="Button__label">{{ $label }}</span>@endif
                @if($description)<span class="Button__description">{{ $description }}</span>@endif
            </span>
            @isset($rightIcon)
                <span class="Button__icon Button__icon--right">{{ $rightIcon }}</span>
            @endisset
        @else
            @isset($leftIcon)
                <span class="Button__icon Button__icon--left">{{ $leftIcon }}</span>
            @endisset
            @if($label)
                <span class="Button__label">{{ $label }}</span>
            @else
                {{ $slot }}
            @endif
            @isset($rightIcon)
                <span class="Button__icon Button__icon--right">{{ $rightIcon }}</span>
            @endisset
        @endif
    </span>
    @if($loading)
        <span class="Button__spinner">
            <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="3" stroke-linecap="round" opacity="0.25" />
                <path d="M12 2a10 10 0 0 1 10 10" stroke="currentColor" stroke-width="3" stroke-linecap="round" />
            </svg>
        </span>
    @endif
</button>
