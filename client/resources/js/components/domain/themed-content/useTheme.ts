import { ref, readonly } from 'vue'
import axios from 'axios'
import type { ThemeDefinition } from './types'

const themeCache = new Map<string, ThemeDefinition>()

export function useTheme() {
  const theme = ref<ThemeDefinition | null>(null)
  const isLoading = ref(false)
  const error = ref<string | null>(null)

  async function fetchTheme(themeId: string) {
    // Check cache first
    if (themeCache.has(themeId)) {
      theme.value = themeCache.get(themeId)!
      return
    }

    isLoading.value = true
    error.value = null
    try {
      const response = await axios.get(`/api/themes/${themeId}`)
      if (response.data.success && response.data.theme) {
        const def = response.data.theme.definition as ThemeDefinition
        themeCache.set(themeId, def)
        theme.value = def
      }
    } catch (err) {
      error.value = 'Failed to load theme'
      console.error('[useTheme] Failed to fetch theme:', err)
    } finally {
      isLoading.value = false
    }
  }

  return {
    theme: readonly(theme),
    isLoading: readonly(isLoading),
    error: readonly(error),
    fetchTheme,
  }
}

export type { ThemeDefinition }
