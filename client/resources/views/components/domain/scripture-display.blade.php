@props([
    'size'             => 'Default',
    'passageReference' => '',
    'verses'           => [],
])

@php
    $classes = cva('ScriptureDisplay', [
        'variants' => [
            'size' => [
                'Default' => 'ScriptureDisplay--size-default',
                'Large'   => 'ScriptureDisplay--size-large',
            ],
        ],
        'defaultVariants' => ['size' => 'Default'],
    ], ['size' => $size]);
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    <h2 class="ScriptureDisplay__reference">{{ $passageReference }}</h2>
    <div class="ScriptureDisplay__verses">
        @foreach($verses as $verse)
            <div class="ScriptureDisplay__verse">
                <span class="ScriptureDisplay__verse-number">{{ $verse['number'] }}</span>
                <span class="ScriptureDisplay__verse-text">{{ $verse['text'] }}</span>
            </div>
        @endforeach
    </div>
</div>
