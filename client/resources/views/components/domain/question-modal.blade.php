@props([
    'title'       => '',
    'description' => '',
])

<div {{ $attributes->merge(['class' => 'QuestionModal']) }}>
    <h2 class="QuestionModal__title">{{ $title }}</h2>
    <p class="QuestionModal__description">{{ $description }}</p>
    {{ $slot }}
</div>
