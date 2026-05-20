@props([
    'size'     => 'Default',
    'question' => '',
    'href'     => null,
])

@php
    $classes = cva('QuestionButton', [
        'variants' => [
            'size' => [
                'Default' => 'QuestionButton--size-default',
                'Small'   => 'QuestionButton--size-small',
            ],
        ],
        'defaultVariants' => ['size' => 'Default'],
    ], ['size' => $size]);

    $iconSize = $size === 'Small' ? 16 : 18;
@endphp

@if($href)
    <a href="{{ $href }}" {{ $attributes->merge(['class' => $classes]) }}>
        <svg
            class="QuestionButton__icon"
            width="{{ $iconSize }}"
            height="{{ $iconSize }}"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
        >
            <circle cx="12" cy="12" r="10" />
            <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3" />
            <line x1="12" y1="17" x2="12.01" y2="17" />
        </svg>
        <span class="QuestionButton__text">{{ $question }}</span>
    </a>
@else
    <button type="button" {{ $attributes->merge(['class' => $classes]) }}>
        <svg
            class="QuestionButton__icon"
            width="{{ $iconSize }}"
            height="{{ $iconSize }}"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
        >
            <circle cx="12" cy="12" r="10" />
            <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3" />
            <line x1="12" y1="17" x2="12.01" y2="17" />
        </svg>
        <span class="QuestionButton__text">{{ $question }}</span>
    </button>
@endif
