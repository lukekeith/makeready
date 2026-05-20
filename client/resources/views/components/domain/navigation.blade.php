@props([
    'selected'  => 'home',
    'avatarUrl' => null,
    'initials'  => '?',
    'homeHref'     => '/home',
    'scheduleHref' => '/schedule',
    'profileHref'  => '/profile',
    'notesHref'    => '/notes',
    'searchHref'   => '/search',
])

<nav {{ $attributes->merge(['class' => 'Navigation']) }}>
    {{-- Home --}}
    <a
        href="{{ $homeHref }}"
        class="Navigation__button{{ $selected === 'home' ? ' Navigation__button--selected' : '' }}"
        aria-label="home"
        @if($selected === 'home') aria-current="page" @endif
    >
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
            <path
                d="M3 9.5L12 3L21 9.5V20C21 20.5304 20.7893 21.0391 20.4142 21.4142C20.0391 21.7893 19.5304 22 19 22H5C4.46957 22 3.96086 21.7893 3.58579 21.4142C3.21071 21.0391 3 20.5304 3 20V9.5Z"
                fill="{{ $selected === 'home' ? 'white' : 'rgba(255, 255, 255, 0.7)' }}"
            />
            <path
                d="M9 22V12H15V22"
                stroke="{{ $selected === 'home' ? '#252936' : 'rgba(37, 41, 54, 0.7)' }}"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
            />
        </svg>
    </a>

    {{-- Schedule --}}
    <a
        href="{{ $scheduleHref }}"
        class="Navigation__button{{ $selected === 'schedule' ? ' Navigation__button--selected' : '' }}"
        aria-label="schedule"
        @if($selected === 'schedule') aria-current="page" @endif
    >
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
            <rect x="3" y="4" width="18" height="18" rx="2" stroke="{{ $selected === 'schedule' ? 'white' : 'rgba(255, 255, 255, 0.7)' }}" stroke-width="2" />
            <path d="M3 10H21" stroke="{{ $selected === 'schedule' ? 'white' : 'rgba(255, 255, 255, 0.7)' }}" stroke-width="2" />
            <path d="M8 2V6" stroke="{{ $selected === 'schedule' ? 'white' : 'rgba(255, 255, 255, 0.7)' }}" stroke-width="2" stroke-linecap="round" />
            <path d="M16 2V6" stroke="{{ $selected === 'schedule' ? 'white' : 'rgba(255, 255, 255, 0.7)' }}" stroke-width="2" stroke-linecap="round" />
        </svg>
    </a>

    {{-- Profile (avatar) --}}
    <a
        href="{{ $profileHref }}"
        class="Navigation__button{{ $selected === 'profile' ? ' Navigation__button--selected' : '' }}"
        aria-label="profile"
        @if($selected === 'profile') aria-current="page" @endif
    >
        <x-primitive.avatar
            :src="$avatarUrl"
            :fallback="$initials"
            class="Navigation__avatar"
        />
    </a>

    {{-- Notes --}}
    <a
        href="{{ $notesHref }}"
        class="Navigation__button{{ $selected === 'notes' ? ' Navigation__button--selected' : '' }}"
        aria-label="notes"
        @if($selected === 'notes') aria-current="page" @endif
    >
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
            <path
                d="M14 2H6C5.46957 2 4.96086 2.21071 4.58579 2.58579C4.21071 2.96086 4 3.46957 4 4V20C4 20.5304 4.21071 21.0391 4.58579 21.4142C4.96086 21.7893 5.46957 22 6 22H18C18.5304 22 19.0391 21.7893 19.4142 21.4142C19.7893 21.0391 20 20.5304 20 20V8L14 2Z"
                stroke="{{ $selected === 'notes' ? 'white' : 'rgba(255, 255, 255, 0.7)' }}"
                stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
            />
            <path d="M14 2V8H20" stroke="{{ $selected === 'notes' ? 'white' : 'rgba(255, 255, 255, 0.7)' }}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
            <path d="M16 13H8" stroke="{{ $selected === 'notes' ? 'white' : 'rgba(255, 255, 255, 0.7)' }}" stroke-width="2" stroke-linecap="round" />
            <path d="M16 17H8" stroke="{{ $selected === 'notes' ? 'white' : 'rgba(255, 255, 255, 0.7)' }}" stroke-width="2" stroke-linecap="round" />
        </svg>
    </a>

    {{-- Search --}}
    <a
        href="{{ $searchHref }}"
        class="Navigation__button{{ $selected === 'search' ? ' Navigation__button--selected' : '' }}"
        aria-label="search"
        @if($selected === 'search') aria-current="page" @endif
    >
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
            <circle cx="11" cy="11" r="7" stroke="{{ $selected === 'search' ? 'white' : 'rgba(255, 255, 255, 0.7)' }}" stroke-width="2" />
            <path d="M21 21L16.5 16.5" stroke="{{ $selected === 'search' ? 'white' : 'rgba(255, 255, 255, 0.7)' }}" stroke-width="2" stroke-linecap="round" />
        </svg>
    </a>
</nav>
