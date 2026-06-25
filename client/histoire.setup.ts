// Histoire global setup (Vue 3).
//
// Loads the app's global stylesheet so every story renders with the real
// design-system tokens (_tokens / _palette / _semantic) and component CSS —
// the same :root custom properties the live client uses. Then layers the dark
// canvas backdrop on top. Without this, stories would render with undefined
// token vars and a white background.
import { defineSetupVue3 } from '@histoire/plugin-vue'
import { createPinia } from 'pinia'

// Global tokens + reset + component styles (pulls in _semantic.scss → dark).
import './resources/css/app.scss'
// Dark canvas backdrop for the preview sandbox (must come after app.scss).
import './histoire.dark.css'

export const setupVue3 = defineSetupVue3(({ app }) => {
  // Pinia so the modal + toast stores resolve in overlay stories (mirrors how
  // resources/js/app.js installs a single Pinia across all islands).
  app.use(createPinia())
})
