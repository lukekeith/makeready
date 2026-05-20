@props([
    'passageReference' => '',
    'verses'           => [],
    'blocks'           => [],
])

<div {{ $attributes->merge(['class' => 'ReadVerseModal']) }}>
    <h2 class="ReadVerseModal__reference">{{ $passageReference }}</h2>

    @if(count($blocks) > 0)
        @foreach($blocks as $block)
            <div class="ReadVerseModal__block">
                @if(!empty($block['title']))
                    <h3 class="ReadVerseModal__block-title">{{ $block['title'] }}</h3>
                @endif
                @if(($block['type'] ?? '') === 'scripture' && !empty($block['verses']))
                    <div class="ReadVerseModal__verses">
                        @foreach($block['verses'] as $verse)
                            <div class="ReadVerseModal__verse">
                                <span class="ReadVerseModal__verse-number">{{ $verse['number'] }}</span>
                                <span class="ReadVerseModal__verse-text">{{ $verse['text'] }}</span>
                            </div>
                        @endforeach
                    </div>
                @elseif(!empty($block['content']))
                    <div class="ReadVerseModal__text-content">{!! $block['content'] !!}</div>
                @endif
            </div>
        @endforeach
    @elseif(count($verses) > 0)
        <div class="ReadVerseModal__verses">
            @foreach($verses as $verse)
                <div class="ReadVerseModal__verse">
                    <span class="ReadVerseModal__verse-number">{{ $verse['number'] }}</span>
                    <span class="ReadVerseModal__verse-text">{{ $verse['text'] }}</span>
                </div>
            @endforeach
        </div>
    @endif

    {{ $slot }}
</div>
