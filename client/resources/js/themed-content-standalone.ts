import { createApp, h, ref } from 'vue'
import ThemedContent from './components/domain/themed-content/ThemedContent.vue'

// State that the native app can inject into
const content = ref('')
const themeDefinition = ref<any>(null)
const contentFormat = ref('markdown')
const sourceReference = ref<any>(undefined)
const verses = ref<any[]>([])
const isLocked = ref(false)

const app = createApp({
  setup() {
    return () => h(ThemedContent, {
      content: content.value,
      themeId: undefined,            // Always bypass the API fetch in standalone mode
      themeDefinition: themeDefinition.value, // Inject definition directly
      contentFormat: contentFormat.value,
      sourceReference: sourceReference.value,
      verses: verses.value,
      isLocked: isLocked.value,
      onPhaseChange: (index: number) => {
        window.webkit?.messageHandlers?.themeEvent?.postMessage({
          type: 'phase-change',
          index,
        })
      },
      onSequenceComplete: () => {
        window.webkit?.messageHandlers?.themeEvent?.postMessage({
          type: 'sequence-complete',
        })
      },
    })
  },
})

app.mount('#app')

// Expose API for native bridge
;(window as any).renderTheme = (data: {
  content: string
  theme: any
  contentFormat?: string
  sourceReference?: any
  verses?: any[]
  isLocked?: boolean
}) => {
  content.value = data.content
  themeDefinition.value = data.theme ?? null
  contentFormat.value = data.contentFormat ?? 'markdown'
  sourceReference.value = data.sourceReference
  verses.value = data.verses ?? []
  isLocked.value = data.isLocked ?? false
}

;(window as any).advancePhase = () => {
  // Dispatch a click event to trigger tap-to-advance
  document.querySelector('.ThemedSequencePlayer')?.dispatchEvent(new MouseEvent('click'))
}

// TypeScript declarations for webkit bridge
declare global {
  interface Window {
    webkit?: {
      messageHandlers?: {
        themeEvent?: {
          postMessage: (message: any) => void
        }
      }
    }
  }
}
