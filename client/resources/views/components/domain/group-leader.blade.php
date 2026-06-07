@props([
    'name'       => '',
    'avatarUrl'  => null,
    'sinceLabel' => null,  // formatted date, e.g. "July 17, 2024"
    'phone'      => null,
    'email'      => null,
])

@php
    // Format the leader's phone as "214.123.4567": digits only, drop a leading
    // US country code, group as 3.3.4. Anything that isn't a 10-digit number
    // falls back to the raw value. The tel: link keeps the dialable digits.
    $phoneDisplay = $phone;
    $phoneHref = null;
    if ($phone) {
        $digits = preg_replace('/\D/', '', (string) $phone);
        if (strlen($digits) === 11 && str_starts_with($digits, '1')) {
            $digits = substr($digits, 1);
        }
        if (strlen($digits) === 10) {
            $phoneDisplay = substr($digits, 0, 3) . '.' . substr($digits, 3, 3) . '.' . substr($digits, 6);
        }
        $phoneHref = preg_replace('/[^0-9+]/', '', (string) $phone);
    }
@endphp

{{-- GroupLeader — bordered leader card (avatar, name, "leader since", contact).
     Figma: Make-Ready-Mobile "GroupLeader" (node 3141:523). --}}
<div {{ $attributes->merge(['class' => 'GroupLeader']) }}>
    <x-primitive.avatar
        :src="$avatarUrl"
        :name="$name"
        :alt="$name"
        :size="80"
        class="GroupLeader__avatar"
    />
    <div class="GroupLeader__body">
        <div class="GroupLeader__name-block">
            <p class="GroupLeader__name">{{ $name }}</p>
            <p class="GroupLeader__since">
                Group leader{{ $sinceLabel ? ' since ' . $sinceLabel : '' }}
            </p>
        </div>

        @if($phone || $email)
            <div class="GroupLeader__contact">
                @if($phone)
                    <a class="GroupLeader__contact-link" href="tel:{{ $phoneHref }}">{{ $phoneDisplay }}</a>
                @endif
                @if($phone && $email)
                    <span class="GroupLeader__contact-dot" aria-hidden="true"></span>
                @endif
                @if($email)
                    <a class="GroupLeader__contact-link" href="mailto:{{ $email }}">{{ $email }}</a>
                @endif
            </div>
        @endif
    </div>
</div>
