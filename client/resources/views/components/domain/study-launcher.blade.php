@props([
    'title'          => '',
    'description'    => null,
    'coverImageUrl'  => null,
    'backHref'       => null,
])

<div {{ $attributes->merge(['class' => 'StudyLauncher']) }}>
    <div class="StudyLauncher__header">
        @if($coverImageUrl)
            <img src="{{ $coverImageUrl }}" alt="{{ $title }}" class="StudyLauncher__header-image" />
        @endif
        <div class="StudyLauncher__header-gradient"></div>

        <div class="StudyLauncher__header-top">
            @if($backHref)
                <a href="{{ $backHref }}" class="StudyLauncher__back-button" aria-label="Go back">
                    <svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <polyline points="15,18 9,12 15,6" />
                    </svg>
                </a>
            @endif
        </div>

        <div class="StudyLauncher__header-details">
            <h1 class="StudyLauncher__header-title">{{ $title }}</h1>
            @if($description)
                <p class="StudyLauncher__header-description">{{ $description }}</p>
            @endif
        </div>
    </div>

    <div class="StudyLauncher__content">
        @isset($buttons)
            <div class="StudyLauncher__buttons">{{ $buttons }}</div>
        @endisset
        {{ $slot }}
    </div>
</div>
