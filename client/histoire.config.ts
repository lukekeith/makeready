import { HstVue } from '@histoire/plugin-vue'
import { defineConfig } from 'histoire'
import { fileURLToPath } from 'url'
import { dirname, resolve } from 'path'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

export default defineConfig({
  plugins: [HstVue()],
  storyGlob: ['resources/js/components/**/*.story.vue', 'resources/js/pages/**/*.story.vue'],
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
