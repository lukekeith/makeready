@props([
    'variant'           => 'Default',
    'title'             => null,
    'leftLink'          => null,
    'rightLink'         => null,
    'leftHref'          => null,
    'rightHref'         => null,
    'showDropdown'      => false,
    'leftIconDisabled'  => false,
    'leftLinkMuted'     => false,
    'leftLinkDisabled'  => false,
    'rightIconDisabled' => false,
    'rightLinkWhite'    => false,
    'rightLinkDisabled' => false,
])

@php
    $classes = cva('PageTitle', [
        'variants' => [
            'variant' => [
                'Default' => 'PageTitle--default',
            ],
        ],
        'defaultVariants' => ['variant' => 'Default'],
    ], ['variant' => $variant]);
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    <div class="PageTitle__container">
        {{-- Left content --}}
        <div class="PageTitle__left">
            @isset($leftIcon)
                @if($leftHref)
                    <a
                        href="{{ $leftHref }}"
                        class="PageTitle__icon-button{{ $leftIconDisabled ? ' PageTitle__icon-button--disabled' : '' }}"
                    >{{ $leftIcon }}</a>
                @else
                    <button
                        type="button"
                        class="PageTitle__icon-button{{ $leftIconDisabled ? ' PageTitle__icon-button--disabled' : '' }}"
                        @if($leftIconDisabled) disabled @endif
                    >{{ $leftIcon }}</button>
                @endif
            @elseif($leftLink)
                @php
                    $leftBtnClass = 'PageTitle__link-button';
                    if ($leftLinkMuted)    $leftBtnClass .= ' PageTitle__link-button--muted';
                    if ($leftLinkDisabled) $leftBtnClass .= ' PageTitle__link-button--disabled';
                @endphp
                @if($leftHref)
                    <a href="{{ $leftHref }}" class="{{ $leftBtnClass }}">{{ $leftLink }}</a>
                @else
                    <button type="button" class="{{ $leftBtnClass }}" @if($leftLinkDisabled) disabled @endif>{{ $leftLink }}</button>
                @endif
            @endisset
        </div>

        {{-- Center title --}}
        @if($title)
            <div class="PageTitle__center">
                <span class="PageTitle__title">{{ $title }}</span>
                @if($showDropdown)
                    <button type="button" class="PageTitle__dropdown-button">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                            <path d="M6 9L12 15L18 9" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                        </svg>
                    </button>
                @endif
            </div>
        @endif

        {{-- Right content --}}
        <div class="PageTitle__right">
            @isset($rightIcon)
                @if($rightHref)
                    <a
                        href="{{ $rightHref }}"
                        class="PageTitle__icon-button{{ $rightIconDisabled ? ' PageTitle__icon-button--disabled' : '' }}"
                    >{{ $rightIcon }}</a>
                @else
                    <button
                        type="button"
                        class="PageTitle__icon-button{{ $rightIconDisabled ? ' PageTitle__icon-button--disabled' : '' }}"
                        @if($rightIconDisabled) disabled @endif
                    >{{ $rightIcon }}</button>
                @endif
            @elseif($rightLink)
                @php
                    $rightBtnClass = 'PageTitle__link-button';
                    if ($rightLinkWhite)    $rightBtnClass .= ' PageTitle__link-button--white';
                    if ($rightLinkDisabled) $rightBtnClass .= ' PageTitle__link-button--disabled';
                @endphp
                @if($rightHref)
                    <a href="{{ $rightHref }}" class="{{ $rightBtnClass }}">{{ $rightLink }}</a>
                @else
                    <button type="button" class="{{ $rightBtnClass }}" @if($rightLinkDisabled) disabled @endif>{{ $rightLink }}</button>
                @endif
            @endisset
        </div>
    </div>
</div>
