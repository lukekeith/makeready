{{-- resources/views/pages/lesson-preview-authed.blade.php --}}
{{-- Authenticated full-lesson preview — fully interactive with preview state storage. --}}
{{-- Synthetic pvw- IDs route save actions to PreviewState instead of real enrollment tables. --}}
{{-- Served by PreviewController::authenticatedLessonPreview and ::previewLesson. --}}
@extends('layouts.home')

@section('title', ($lessonData['title'] ?? 'Lesson Preview') . ' — MakeReady')

@php
    // isPreview=false + synthetic pvw-{token} IDs → LessonIsland fires normal
    // save actions, but Laravel routes intercept the pvw- prefix and proxy to
    // the preview state API instead of the real member endpoints.
    $pvwToken = $previewToken ?? '';
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
