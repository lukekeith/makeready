<script setup lang="ts">
import '../../css/app.scss'
</script>

<template>
  <Story title="Pages/Public Home" group="pages">
    <Variant title="Default">
      <div class="PublicHomePage">
        <div class="PublicHomePage__background">
          <img src="/home-background-full.png" alt="" class="PublicHomePage__background-full" />
          <img src="/home-background.png" alt="" class="PublicHomePage__background-mobile" />
        </div>

        <main class="PublicHomePage__container">
          <div class="PublicHomePage__hero">
            <div class="PublicHomePage__logo-section">
              <img src="/mr-logo.svg" alt="MakeReady" class="PublicHomePage__logo" />
              <h1 class="PublicHomePage__title">MakeReady</h1>
              <p class="PublicHomePage__subtitle">Personal growth through human connection, accountability, and study.</p>
            </div>
          </div>

          <div class="PublicHomePage__actions">
            <button type="button" class="Button Button--jump-primary">
              <span class="Button__content">
                <span class="Button__details">
                  <span class="Button__label">Join a Group</span>
                  <span class="Button__description">Enter a code from your group leader</span>
                </span>
                <span class="Button__icon Button__icon--right">
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
                </span>
              </span>
            </button>

            <button type="button" class="Button Button--jump">
              <span class="Button__content">
                <span class="Button__details">
                  <span class="Button__label">Member Login</span>
                  <span class="Button__description">Login with your phone number</span>
                </span>
                <span class="Button__icon Button__icon--right">
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
                </span>
              </span>
            </button>

            <button type="button" class="Button Button--jump">
              <span class="Button__content">
                <span class="Button__details">
                  <span class="Button__label">Join an Event</span>
                  <span class="Button__description">Enter an event code</span>
                </span>
                <span class="Button__icon Button__icon--right">
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
                </span>
              </span>
            </button>

            <button type="button" class="Button Button--jump">
              <span class="Button__content">
                <span class="Button__details">
                  <span class="Button__label">Join a Study</span>
                  <span class="Button__description">Open a study link</span>
                </span>
                <span class="Button__icon Button__icon--right">
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
                </span>
              </span>
            </button>
          </div>

          <div class="PublicHomePage__footer">
            <button class="PublicHomePage__link">Privacy policy</button>
            <span class="PublicHomePage__dot" aria-hidden="true">&#183;</span>
            <button class="PublicHomePage__link">Terms of use</button>
          </div>
        </main>
      </div>
    </Variant>
  </Story>
</template>
