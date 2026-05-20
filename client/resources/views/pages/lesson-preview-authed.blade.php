{{-- resources/views/pages/lesson-preview-authed.blade.php --}}
{{-- Authenticated full-lesson preview — mirrors activity-preview-authed but for a whole lesson. --}}
{{-- Mounts LessonIsland with isPreview=true so note submission is disabled; no token required. --}}
{{-- Served by PreviewController::authenticatedLessonPreview for the iPhone WKWebView and desktop creators. --}}
@extends('layouts.home')

@section('title', ($lessonData['title'] ?? 'Lesson Preview') . ' — MakeReady')

@php
    // isPreview=true → LessonIsland skips POST calls (submitNote / video-progress).
    // groupId + lessonScheduleId are empty strings; LessonIsland tolerates this when isPreview=true.
    // previewToken is omitted — this preview is authenticated, not token-based.
    $islandProps = json_encode([
        'lessonData'       => $lessonData,
        'groupId'          => '',
        'lessonScheduleId' => '',
        'initialStep'      => (int) $step,
        'isPreview'        => true,
    ], JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_AMP | JSON_HEX_QUOT);
@endphp

@section('content')
<div
    data-vue="LessonIsland"
    data-props="{{ $islandProps }}"
></div>
@endsection
