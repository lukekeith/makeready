{{-- resources/views/pages/lesson-preview.blade.php --}}
{{-- Public lesson preview page — mounts LessonIsland with isPreview=true (disables note saving) --}}
{{-- React: LessonPreviewPage → LessonActivity (root class LessonActivity, no outer wrapper) --}}
@extends('layouts.home')

@section('title', ($lessonData['title'] ?? 'Lesson Preview') . ' — MakeReady')

@php
    // Synthetic pvw-{token} IDs route save actions to preview state storage.
    // isPreview=false when we have a token so LessonIsland fires normal actions.
    $pvwToken = $token ?? '';
    $islandProps = json_encode([
        'lessonData'       => $lessonData,
        'groupId'          => $pvwToken ? 'pvw-' . $pvwToken : '',
        'lessonScheduleId' => $pvwToken ? 'pvw-' . ($lessonId ?? '') : '',
        'initialStep'      => (int) $step,
        'isPreview'        => empty($pvwToken),
        'previewToken'     => $pvwToken,
    ], JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_AMP | JSON_HEX_QUOT);
@endphp

@section('content')
<div
    data-vue="LessonIsland"
    data-props="{{ $islandProps }}"
></div>
@endsection
