{{-- resources/views/pages/lesson-preview.blade.php --}}
{{-- Public lesson preview page — mounts LessonIsland with isPreview=true (disables note saving) --}}
{{-- React: LessonPreviewPage → LessonActivity (root class LessonActivity, no outer wrapper) --}}
@extends('layouts.home')

@section('title', ($lessonData['title'] ?? 'Lesson Preview') . ' — MakeReady')

@php
    // Encode props safely for embedding in data attribute.
    // isPreview=true disables AJAX POST calls (submitNote) inside LessonIsland.
    // groupId and lessonScheduleId are empty strings — LessonIsland handles gracefully when isPreview=true.
    $islandProps = json_encode([
        'lessonData'       => $lessonData,
        'groupId'          => '',
        'lessonScheduleId' => '',
        'initialStep'      => (int) $step,
        'isPreview'        => true,
        'previewToken'     => $token,
    ], JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_AMP | JSON_HEX_QUOT);
@endphp

@section('content')
<div
    data-vue="LessonIsland"
    data-props="{{ $islandProps }}"
></div>
@endsection
