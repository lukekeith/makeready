@props(['items' => []])

@if(!empty($items))
<div class="Timeline">
    <div class="Timeline__line"></div>
    @foreach($items as $item)
    <div class="Timeline__item">
        <div class="Timeline__indicator" @if($loop->first) data-first="true" @endif></div>
        <div class="Timeline__content">
            <span class="Timeline__title">{{ $item['title'] ?? '' }}</span>
            @if(!empty($item['description']))
            <span class="Timeline__description">{{ $item['description'] }}</span>
            @endif
            @if(!empty($item['label']))
            <span class="Timeline__label">{{ $item['label'] }}</span>
            @endif
        </div>
    </div>
    @endforeach
</div>
@endif
