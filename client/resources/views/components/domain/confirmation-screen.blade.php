{{--
    Reusable success/status confirmation screen for the join workflows. Wraps
    `<x-panel.confirmation>` with a default checkmark icon and an optional
    "Return home" link beneath the panel.

    Default icon is a checkmark. Override it by passing a named `icon` slot
    (e.g. a clock icon for the "Request submitted" pending state).

    Actions (CTA buttons like "Continue") are optional — pass them via the
    `action` slot and they render inside the confirmation panel.

    Color variants follow the panel.confirmation API: Green / White / Red /
    Yellow / Purple. Default "Green" uses the muted pattern (20% green bg
    with a solid green icon).

    Example:
        <x-domain.confirmation-screen
            title="You're in!"
            :description="'Welcome to ' . $groupName . '.'"
            :home-url="route('home.public')"
        >
            <x-slot:action>
                <x-primitive.button variant="White" mode="Block"
                    onclick="window.location.href='{{ route('group.home', ['groupId' => $groupId]) }}'">
                    Continue
                </x-primitive.button>
            </x-slot:action>
        </x-domain.confirmation-screen>
--}}

@props([
    'title',
    'description' => '',
    'color'       => 'Green',
    'homeUrl'     => null,
])

<x-panel.confirmation :color="$color" :title="$title" :description="$description">
    <x-slot:icon>
        @isset($icon)
            {{ $icon }}
        @else
            <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6L9 17L4 12"/></svg>
        @endisset
    </x-slot:icon>
    @isset($action)
        <x-slot:action>{{ $action }}</x-slot:action>
    @endisset
</x-panel.confirmation>

@if($homeUrl)
    <x-primitive.button variant="LinkMuted" onclick="window.location.href='{{ $homeUrl }}'">
        <x-slot:leftIcon><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/></svg></x-slot:leftIcon>
        Return home
    </x-primitive.button>
@endif
