@props([
    'isLoading'       => false,
    'loadError'       => null,
    'saveError'       => null,
    'isSaving'        => false,
    'isValid'         => false,
    'firstName'       => '',
    'lastName'        => '',
    'gender'          => '',
    'birthday'        => '',
    'displayAvatarUrl' => null,
    'initials'        => '?',
    'hasEmail'        => false,
])

@if($isLoading)
    <div class="EditProfileModalContent EditProfileModalContent--loading">
        <x-primitive.loading variant="Bars" color="White" size="Lg" />
    </div>
@elseif($loadError)
    <div class="EditProfileModalContent EditProfileModalContent--error">
        <p class="EditProfileModalContent__error-text">{{ $loadError }}</p>
    </div>
@else
    <div {{ $attributes->merge(['class' => 'EditProfileModalContent']) }}>
        <div class="EditProfileModalContent__header">
            <div class="EditProfileModalContent__header-cancel">
                <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <line x1="18" y1="6" x2="6" y2="18" />
                    <line x1="6" y1="6" x2="18" y2="18" />
                </svg>
            </div>
            <h2 class="EditProfileModalContent__header-title">Edit profile</h2>
            <div class="EditProfileModalContent__header-save">Save</div>
        </div>

        <div class="EditProfileModalContent__content">
            <div class="EditProfileModalContent__avatar-button">
                <x-primitive.avatar
                    :src="$displayAvatarUrl"
                    :fallback="$initials"
                    :size="210"
                    class="EditProfileModalContent__avatar"
                />
            </div>

            @if($saveError)
                <p class="EditProfileModalContent__save-error">{{ $saveError }}</p>
            @endif

            <x-domain.profile-form
                :first-name="$firstName"
                :last-name="$lastName"
                :gender="$gender"
                :birthday="$birthday"
                :show-success-message="false"
                :disabled="$isSaving"
            />
        </div>
    </div>
@endif
