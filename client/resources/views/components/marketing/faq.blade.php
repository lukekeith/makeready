@props(['faqs' => []])

@if(!empty($faqs))
<section class="MarketingFaq" aria-labelledby="faq-heading">
    <h5 class="Eyebrow">Questions</h5>
    <h2 id="faq-heading">A few things leaders ask first.</h2>
    <div class="MarketingFaq__grid">
        @foreach($faqs as $faq)
            <details class="MarketingFaq__item">
                <summary>{{ $faq['question'] ?? '' }}</summary>
                <p>{{ $faq['answer'] ?? '' }}</p>
            </details>
        @endforeach
    </div>
</section>
@endif
