<script setup lang="ts">
// Reusable centered confirmation block (icon + title + message + actions).
// Use anywhere a success/confirmation message is shown. Full width, flex column,
// centered, 24px gap. Pass the icon via the #icon slot, action buttons via
// #actions (or default slot); style buttons with .ConfirmationMessage__action.
import './confirmation-message.scss'

interface Props {
  title?: string
  message?: string
}

defineProps<Props>()
</script>

<template>
  <div class="ConfirmationMessage">
    <div v-if="$slots.icon" class="ConfirmationMessage__icon">
      <slot name="icon" />
    </div>

    <h2 v-if="title" class="ConfirmationMessage__title">{{ title }}</h2>

    <p v-if="message" class="ConfirmationMessage__message">{{ message }}</p>

    <div v-if="$slots.actions || $slots.default" class="ConfirmationMessage__actions">
      <slot name="actions" />
      <slot />
    </div>
  </div>
</template>
