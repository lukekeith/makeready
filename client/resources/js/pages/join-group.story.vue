<script setup lang="ts">
import '../../css/app.scss'
</script>

<template>
  <Story title="Pages/Join Group" group="pages">
    <Variant title="Info Step">
      <div class="JoinPage">
        <div class="JoinPage__container">
          <div class="JoinPage__cards">
            <div class="GroupLeaderNote GroupLeaderNote--default GroupLeaderNote--invite">
              <span class="Avatar GroupLeaderNote__avatar">
                <span class="Avatar__fallback">LK</span>
              </span>
              <div class="GroupLeaderNote__content">
                <p class="GroupLeaderNote__text">
                  You have been invited by <strong>Luke Keith</strong> to join a private group.
                </p>
              </div>
            </div>

            <div class="GroupInfoCard GroupInfoCard--button-layout-vertical">
              <div class="GroupInfoCard__photo">
                <img src="https://picsum.photos/seed/grp/440/200" alt="Young Professionals" class="GroupInfoCard__photo-image" />
                <div class="GroupInfoCard__gradient">
                  <div class="GroupInfoCard__details">
                    <h2 class="GroupInfoCard__name">Young Professionals</h2>
                    <div class="GroupInfoCard__meta">
                      <div class="GroupInfoCard__private">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><rect x="3" y="11" width="18" height="11" rx="2" ry="2" stroke="currentColor" stroke-width="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>
                        <span>Private group</span>
                      </div>
                      <div class="GroupInfoCard__members">
                        <span class="GroupInfoCard__members-count">5</span>
                        <span class="GroupInfoCard__members-label">members</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              <div class="GroupInfoCard__actions">
                <button class="Button Button--white Button--size-default Button--mode-block">
                  <span class="Button__content">Continue</span>
                </button>
                <button class="Button Button--secondary Button--size-default Button--mode-block">
                  <span class="Button__content">Change group</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Variant>

    <Variant title="Profile Step">
      <div class="JoinPage">
        <div class="JoinPage__container">
          <div class="JoinPage__content">
            <div class="StepTitle">
              <h1 class="StepTitle__heading">Enter your info</h1>
              <p class="StepTitle__description">Tell us a bit about yourself to complete your profile.</p>
            </div>
            <div class="JoinPage__button-wrapper">
              <button class="Button Button--white Button--size-default Button--mode-block">
                <span class="Button__content">Next</span>
              </button>
              <button class="Button Button--secondary Button--size-default Button--mode-block">
                <span class="Button__content">Change group</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </Variant>

    <Variant title="Confirmed (Pending)">
      <div class="JoinPage">
        <div class="JoinPage__container">
          <div class="Confirmation Confirmation--color-white">
            <div class="Confirmation__icon-circle">
              <div class="Confirmation__icon">
                <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
              </div>
            </div>
            <div class="Confirmation__message">
              <div class="Confirmation__details">
                <h1 class="Confirmation__title">Request submitted</h1>
                <p class="Confirmation__description">Your request to join Young Professionals has been submitted.</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Variant>

    <Variant title="Confirmed (Approved)">
      <div class="JoinPage">
        <div class="JoinPage__container">
          <div class="Confirmation Confirmation--color-green">
            <div class="Confirmation__icon-circle">
              <div class="Confirmation__icon">
                <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6L9 17L4 12"/></svg>
              </div>
            </div>
            <div class="Confirmation__message">
              <div class="Confirmation__details">
                <h1 class="Confirmation__title">You're in!</h1>
                <p class="Confirmation__description">Welcome to Young Professionals!</p>
                <div class="Confirmation__action">
                  <button class="Button Button--white Button--size-default Button--mode-block">
                    <span class="Button__content">Continue</span>
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Variant>
  </Story>
</template>
