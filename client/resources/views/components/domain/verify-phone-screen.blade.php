{{--
    Verify-phone step content: IconCircle + StepTitle + VerifyCode input + optional
    "Return home" link. Drop into the existing `{pageClass}__cards` wrapper of any
    join flow — EventJoinPage, StudyJoinPage, JoinPage (group). The `pageClass`
    prop parameterizes the BEM namespace so this component reuses each flow's
    existing `__content` and `__code-wrapper` styles without duplication.

    Example:
        <div class="EventJoinPage">
            <div class="EventJoinPage__container">
                <div class="EventJoinPage__cards">
                    <x-domain.verify-phone-screen
                        :ajax-verify-url="$ajaxVerifyUrl"
                        :phone="$phone ?? null"
                        page-class="EventJoinPage"
                        :home-url="route('home.public')"
                    />
                </div>
            </div>
        </div>
--}}

@props([
    'ajaxVerifyUrl',
    'phone'       => null,
    'pageClass'   => 'JoinPage',
    'title'       => 'Verify phone',
    'description' => 'Enter the 6-digit code sent to your phone',
    'homeUrl'     => null,
])

<div class="{{ $pageClass }}__content">
    <div class="StepTitle StepTitle--with-icon">
        <x-primitive.icon-circle variant="purple" size="lg">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12.01" y2="18"/></svg>
        </x-primitive.icon-circle>
        <h1 class="StepTitle__heading">{{ $title }}</h1>
        <p class="StepTitle__description">{{ $description }}</p>
    </div>

    <div class="{{ $pageClass }}__code-wrapper">
        <div
            data-vue="JoinVerifyIsland"
            data-props="{{ json_encode([
                'ajaxVerifyUrl' => $ajaxVerifyUrl,
                'phone'         => $phone,
            ]) }}"
        ></div>
    </div>
</div>

@if($homeUrl)
    <x-primitive.button variant="LinkMuted" onclick="window.location.href='{{ $homeUrl }}'">
        <x-slot:leftIcon><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/></svg></x-slot:leftIcon>
        Return home
    </x-primitive.button>
@endif
