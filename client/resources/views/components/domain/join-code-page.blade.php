@props([
    'state'       => 'Default',
    'title'       => 'Join a group',
    'description' => 'Enter the 6-character code shared by your group leader to join their group.',
    'buttonLabel' => 'Join Group',
    'isLoading'   => false,
    'error'       => null,
    'disabled'    => false,
])

@php
    $derivedState = $state;
    if ($state === 'Default') {
        if ($isLoading)  $derivedState = 'Loading';
        elseif ($error)  $derivedState = 'Error';
    }

    $classes = cva('JoinCodePage', [
        'variants' => [
            'state' => [
                'Default' => 'JoinCodePage--default',
                'Loading' => 'JoinCodePage--loading',
                'Error'   => 'JoinCodePage--error',
            ],
        ],
        'defaultVariants' => ['state' => 'Default'],
    ], ['state' => $derivedState]);
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    <div class="JoinCodePage__container">
        <img src="/mr-logo.svg" alt="MakeReady" class="JoinCodePage__logo" />
        <h1 class="JoinCodePage__title">{{ $title }}</h1>
        <p class="JoinCodePage__description">{{ $description }}</p>

        <div class="JoinCodePage__input-wrapper">
            {{ $slot }}
        </div>

        @if($error)
            <p class="JoinCodePage__error">{{ $error }}</p>
        @endif

        <x-primitive.button
            class="JoinCodePage__button"
            variant="White"
            mode="Block"
            :loading="$isLoading"
            :disabled="$disabled || $isLoading"
        >
            {{ $buttonLabel }}
        </x-primitive.button>
    </div>
</div>
