@props([
    'theme'        => 'Dark',
    'title'        => '',
    'showBack'     => true,
    'showNext'     => true,
    'nextDisabled' => false,
    'backLabel'    => 'Prev',
    'nextLabel'    => 'Next',
    'backHref'     => null,
    'nextHref'     => null,
])

@php
    $classes = cva('LessonPageHeader', [
        'variants' => [
            'theme' => [
                'Dark'  => 'LessonPageHeader--theme-dark',
                'Light' => 'LessonPageHeader--theme-light',
            ],
        ],
        'defaultVariants' => ['theme' => 'Dark'],
    ], ['theme' => $theme]);
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    <div class="LessonPageHeader__left">
        @if($showBack)
            @if($backHref)
                <a href="{{ $backHref }}" class="LessonPageHeader__nav-button LessonPageHeader__nav-button--prev">
                    <svg class="LessonPageHeader__icon" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <polyline points="15 18 9 12 15 6" />
                    </svg>
                    <span class="LessonPageHeader__nav-label">{{ $backLabel }}</span>
                </a>
            @else
                <button type="button" class="LessonPageHeader__nav-button LessonPageHeader__nav-button--prev">
                    <svg class="LessonPageHeader__icon" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <polyline points="15 18 9 12 15 6" />
                    </svg>
                    <span class="LessonPageHeader__nav-label">{{ $backLabel }}</span>
                </button>
            @endif
        @endif
    </div>

    <h1 class="LessonPageHeader__title">{{ $title }}</h1>

    <div class="LessonPageHeader__right">
        @if($showNext)
            @php
                $navBtnClass = 'LessonPageHeader__nav-button LessonPageHeader__nav-button--next';
                if ($nextDisabled) $navBtnClass .= ' LessonPageHeader__nav-button--disabled';
                $isFinish = $nextLabel === 'Finish';
            @endphp
            @if($nextHref && !$nextDisabled)
                <a href="{{ $nextHref }}" class="{{ $navBtnClass }}">
                    <span class="LessonPageHeader__nav-label">{{ $nextLabel }}</span>
                    @if($isFinish)
                        <svg class="LessonPageHeader__icon" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <polyline points="20 6 9 17 4 12" />
                        </svg>
                    @else
                        <svg class="LessonPageHeader__icon" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <polyline points="9 18 15 12 9 6" />
                        </svg>
                    @endif
                </a>
            @else
                <button type="button" class="{{ $navBtnClass }}" @if($nextDisabled) disabled @endif>
                    <span class="LessonPageHeader__nav-label">{{ $nextLabel }}</span>
                    @if($isFinish)
                        <svg class="LessonPageHeader__icon" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <polyline points="20 6 9 17 4 12" />
                        </svg>
                    @else
                        <svg class="LessonPageHeader__icon" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <polyline points="9 18 15 12 9 6" />
                        </svg>
                    @endif
                </button>
            @endif
        @endif
    </div>
</div>
