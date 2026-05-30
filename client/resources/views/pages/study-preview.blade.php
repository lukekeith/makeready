{{-- resources/views/pages/study-preview.blade.php --}}
{{-- Public study preview page — no auth required, shows study info and lesson list --}}
{{-- React: StudyPreviewPage → StudyPreview / StudyPreview__viewport / StudyPreview__scroll-container / StudyPreview__header / StudyPreview__lessons --}}
@extends('layouts.home')

@section('title', ($studyData['title'] ?? $studyData['name'] ?? 'Study Preview') . ' — MakeReady')

@php
    $studyTitle = $studyData['title'] ?? $studyData['name'] ?? 'Study Preview';
    $studyDesc  = $studyData['description'] ?? null;
    $coverImageUrl = $studyData['coverImageUrl'] ?? null;
@endphp

@section('content')
<div class="StudyPreview">
    <div class="StudyPreview__viewport">

        <div class="StudyPreview__scroll-container">
            <div class="StudyPreview__header">

                {{-- Header Card (StudyCard mode=Header in React) --}}
                <x-domain.study-card
                    mode="Header"
                    :title="$studyTitle"
                    :description="$studyDesc ?? ''"
                    :cover-image-url="$coverImageUrl"
                />

                {{-- Lessons List --}}
                <div class="StudyPreview__lessons">
                    @if(count($lessons) > 0)
                        @foreach($lessons as $lesson)
                            @php
                                $lessonId    = $lesson['id'] ?? null;
                                $lessonDay   = $lesson['dayNumber'] ?? null;
                                $lessonTitle = $lesson['title'] ?? '';
                                $lessonActivities = $lesson['activities'] ?? [];
                                // Use synthetic pvw- route for interactive preview when we have a token.
                                // Falls back to read-only /preview/lesson/ if no token.
                                $pvw = $token ?? ($previewToken ?? null);
                                $lessonHref  = $lessonId
                                    ? ($pvw
                                        ? '/member/groups/pvw-' . $pvw . '/lessons/pvw-' . $lessonId
                                        : '/preview/lesson/' . $lessonId)
                                    : null;
                            @endphp

                            @if($lessonHref)
                                <a href="{{ $lessonHref }}" class="StudyPreview__lesson-link">
                            @endif

                            <x-domain.study-card
                                mode="LessonList"
                                :title="$lessonTitle"
                                :day-number="$lessonDay"
                                :activities="$lessonActivities"
                            />

                            @if($lessonHref)
                                </a>
                            @endif
                        @endforeach
                    @else
                        <p class="StudyPreview__empty">No lessons available for this study preview.</p>
                    @endif
                </div>

            </div>
        </div>

    </div>
</div>
@endsection
