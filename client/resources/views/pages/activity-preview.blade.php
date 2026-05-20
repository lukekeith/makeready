{{-- resources/views/pages/activity-preview.blade.php --}}
{{-- Standalone activity preview — renders a single activity with no navigation --}}
@extends('layouts.home')

@section('title', ($activityData['title'] ?? 'Activity Preview') . ' — MakeReady')

@php
    // Wrap the single activity in a minimal lesson structure for LessonIsland.
    // singleActivity=true tells LessonIsland to hide all navigation chrome.
    $lessonData = [
        'lesson' => [
            'id' => 'preview',
            'title' => $activityData['title'] ?? 'Preview',
            'activities' => [$activityData],
        ],
    ];

    $islandProps = json_encode([
        'lessonData'       => $lessonData,
        'groupId'          => '',
        'lessonScheduleId' => '',
        'initialStep'      => 1,
        'isPreview'        => true,
        'previewToken'     => $token,
        'singleActivity'   => true,
    ], JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_AMP | JSON_HEX_QUOT);
@endphp

@section('content')
<div
    data-vue="LessonIsland"
    data-props="{{ $islandProps }}"
></div>
@endsection
