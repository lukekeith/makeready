@props([
    'variant'            => 'Default',
    'firstName'          => '',
    'lastName'           => '',
    'birthday'           => '',
    'gender'             => '',
    'showSuccessMessage' => true,
    'disabled'           => false,
    'action'             => null,
    'method'             => 'POST',
])

@php
    $classes = cva('ProfileForm', [
        'variants' => [
            'variant' => [
                'Default' => 'ProfileForm--default',
                'Compact' => 'ProfileForm--compact',
            ],
        ],
        'defaultVariants' => ['variant' => 'Default'],
    ], ['variant' => $variant]);

    $inputSize = $variant === 'Compact' ? 'Compact' : 'Default';
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    @if($showSuccessMessage)
        <p class="ProfileForm__success">Your phone number was successfully verified.</p>
    @endif

    <div class="ProfileForm__fields">
        <x-primitive.mobile-input
            label="First name"
            :value="$firstName"
            :disabled="$disabled"
            :size="$inputSize"
            name="first_name"
        />

        <x-primitive.mobile-input
            label="Last name"
            :value="$lastName"
            :disabled="$disabled"
            :size="$inputSize"
            name="last_name"
        />

        <x-primitive.mobile-select
            label="Gender"
            :value="$gender"
            :options="[['value' => 'male', 'label' => 'Male'], ['value' => 'female', 'label' => 'Female']]"
            placeholder="Select gender"
            :disabled="$disabled"
            :size="$inputSize"
            name="gender"
        />

        <x-primitive.mobile-date
            label="Birthday"
            :value="$birthday"
            :disabled="$disabled"
            :size="$inputSize"
            name="birthday"
        />
    </div>
</div>
