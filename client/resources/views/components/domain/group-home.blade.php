@props([
    'withLeaderButtons' => false,
    'isLoading'         => false,
])

@php
    $postsClass = 'GroupHome__posts';
    if ($withLeaderButtons) {
        $postsClass .= ' GroupHome__posts--with-leader-buttons';
    }
@endphp

<div {{ $attributes->merge(['class' => 'GroupHome']) }}>
    @isset($groupCard){{ $groupCard }}@endisset

    @isset($studies)
        <div class="GroupHome__studies">{{ $studies }}</div>
    @endisset

    @if($isLoading)
        <div class="{{ $postsClass }}">
            <div class="GroupHome__loading-skeleton"></div>
            <div class="GroupHome__loading-skeleton"></div>
        </div>
    @else
        <div class="{{ $postsClass }}">
            @isset($posts)
                {{ $posts }}
            @else
                <div class="GroupHome__empty-state">
                    <p class="GroupHome__empty-title">No posts yet</p>
                    <p class="GroupHome__empty-description">Posts from your group leader will appear here.</p>
                </div>
            @endisset
        </div>
    @endif

    @isset($leaderButtons)
        <div class="GroupHome__leader-buttons">{{ $leaderButtons }}</div>
    @endisset

    @isset($navigation)
        <div class="GroupHome__navigation">{{ $navigation }}</div>
    @endisset
</div>
