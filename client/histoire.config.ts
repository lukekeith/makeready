import { HstVue } from '@histoire/plugin-vue'
import { defineConfig } from 'histoire'
import { fileURLToPath } from 'url'
import { dirname, resolve } from 'path'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

export default defineConfig({
  plugins: [HstVue()],
  setupFile: './histoire.setup.ts',
  storyGlob: ['resources/js/components/**/*.story.vue', 'resources/js/pages/**/*.story.vue'],
  // Default the whole UI to dark; the design system is dark-only.
  theme: {
    title: 'MakeReady Design System',
    defaultColorScheme: 'dark',
    storeColorScheme: false,
  },
  // Canvas-first background presets so any story can be checked on the real
  // app surfaces. First entry (canvas) is the default backdrop.
  backgroundPresets: [
    { label: 'Canvas (#0d101a)', color: '#0d101a', contrastColor: '#ffffff' },
    { label: 'Surface (#252936)', color: '#252936', contrastColor: '#ffffff' },
    { label: 'Section (#191C25)', color: '#191c25', contrastColor: '#ffffff' },
    { label: 'Transparent', color: 'transparent', contrastColor: '#ffffff' },
  ],
  vite: {
    css: {
      preprocessorOptions: {
        scss: {
          // Allow @use 'styles/colors' to resolve to resources/css/styles/_colors.scss
          // Legacy JS API uses 'includePaths'; modern API uses 'loadPaths'
          includePaths: [resolve(__dirname, 'resources/css')],
          loadPaths: [resolve(__dirname, 'resources/css')],
        },
      },
    },
  },
})
