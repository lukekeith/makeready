{{-- resources/views/pages/study-preview.blade.php --}}
{{-- Study preview (leader / public token) — redesigned interactive island (StudyHomeIsland) --}}
@extends('layouts.home')

@section('title', ($studyData['title'] ?? $studyData['name'] ?? 'Study Preview') . ' — MakeReady')

@php
    $studyTitle = $studyData['title'] ?? $studyData['name'] ?? 'Study Preview';
    $studyCover = $studyData['coverImageUrl'] ?? null;
    $pvw        = $token ?? ($previewToken ?? null);

    // Build preview lessons; no dates → island renders without a calendar and never "unavailable".
    $islandLessons = array_map(function ($lesson) use ($pvw) {
        $lessonId = $lesson['id'] ?? null;
        $href = null;
        if ($lessonId) {
            $href = $pvw
                ? '/member/groups/pvw-' . $pvw . '/lessons/pvw-' . $lessonId
                : ($lesson['routes']['lesson'] ?? '/preview/lesson/' . $lessonId);
        }
        return [
            'id'               => $lessonId,
            'dayNumber'        => $lesson['dayNumber'] ?? null,
            'title'            => $lesson['title'] ?? '',
            'scheduledDate'    => null,
            'estimatedMinutes' => $lesson['estimatedMinutes'] ?? null,
            'activities'       => $lesson['activities'] ?? [],
            'href'             => $href,
        ];
    }, $lessons);

    $islandProps = [
        'title'         => $studyTitle,
        'coverImageUrl' => $studyCover,
        'backHref'      => '',
        'isPreview'     => true,
        'lessons'       => $islandLessons,
        'firstDate'     => null,
        'lastDate'      => null,
        'activeDays'    => [],
    ];
@endphp

@section('content')
<div class="StudyHome">
    <div class="StudyHome__viewport">
        <div data-vue="StudyHomeIsland" data-props="{{ json_encode($islandProps, JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_HEX_AMP) }}"></div>
    </div>
</div>
@endsection
