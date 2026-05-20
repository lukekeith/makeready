{{-- resources/views/pages/lesson.blade.php --}}
{{-- Lesson page shell — mounts LessonIsland Vue SPA with full lesson data --}}
{{-- React: LessonPage → LessonActivity (root class LessonActivity, no outer wrapper) --}}
@extends('layouts.home')

@section('title', ($lessonData['lesson']['title'] ?? $lessonData['title'] ?? 'Lesson') . ' — MakeReady')

@php
    // Encode props safely for embedding in data attribute
    $islandProps = json_encode([
        'lessonData'       => $lessonData,
        'groupId'          => $groupId,
        'lessonScheduleId' => $lessonScheduleId,
        'initialStep'      => (int) $step,
        'isPreview'        => false,
    ], JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_AMP | JSON_HEX_QUOT);
@endphp

@section('content')
<div
    data-vue="LessonIsland"
    data-props="{{ $islandProps }}"
></div>
@endsection
