<script setup lang="ts">
// MarkdownEditor — twin of iOS Components/Input/MarkdownEditor.swift.
//
// A WYSIWYG markdown editor card: a fixed formatting toolbar (cardBackground),
// a hairline divider, and a tall (minHeight 200) editor area (backgroundDark).
// The toolbar is constant chrome — H▾ heading menu | list · quote | bold ·
// italic | Aa (clear formatting) | undo · redo — so it is baked into this
// component; only the placeholder and the rendered text change between variants.
//
// KEY PARITY FACT (see the captured iPhone references): in the isolated snapshot
// the iOS `markdownToAttributed()` HTML→AttributedString conversion strips the
// markdown SYNTAX markers (#, **, *, -, >) but renders every block as flat 17pt
// white body text — no heading sizes, no bold/italic, no bullets, no blockquote
// styling. Blank source lines survive as blank rendered lines, which is what
// produces the one-blank-line gap the snapshot shows between blocks while
// consecutive list items sit on adjacent lines. So this twin renders the
// markdown line-by-line with the markers stripped and blanks preserved, exactly
// mirroring the snapshot rather than a "real" markdown renderer.
//
// Fully data-driven via props; BEM mirrors
// resources/css/components/card/markdown-editor.scss.
import { computed } from 'vue'

interface Props {
  placeholder?: string
  markdown?: string
  autoGrow?: boolean
  // ADDITIVE interactive mode (production only; captures never pass it): the
  // editor area becomes a real auto-growing textarea over the raw markdown
  // source and emits update:markdown. Toolbar stays inert chrome for now —
  // a web-platform simplification of the iOS AttributedString editor.
  interactive?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  placeholder: '',
  markdown: '',
  autoGrow: true,
  interactive: false,
})

const emit = defineEmits<{ 'update:markdown': [value: string] }>()

function onInput(e: Event): void {
  const el = e.target as HTMLTextAreaElement
  // Auto-grow: hug content (iOS autoGrow TextEditor).
  el.style.height = 'auto'
  el.style.height = `${el.scrollHeight}px`
  emit('update:markdown', el.value)
}

const isEmpty = computed(() => (props.markdown ?? '').length === 0)

// Strip line-level + inline markdown markers per line, preserving blank lines.
const lines = computed(() =>
  (props.markdown ?? '').split('\n').map((raw) => {
    let t = raw
    t = t.replace(/^\s*#{1,6}\s+/, '') // headings (# .. ######)
    t = t.replace(/^\s*>\s+/, '') // blockquote
    t = t.replace(/^\s*[-*]\s+/, '') // list items
    t = t.replace(/\*\*\*(.+?)\*\*\*/g, '$1') // bold+italic
    t = t.replace(/\*\*(.+?)\*\*/g, '$1') // bold
    t = t.replace(/\*(.+?)\*/g, '$1') // italic
    return t
  }),
)
</script>

<template>
  <div class="MarkdownEditor">
    <!-- Toolbar (constant chrome, all controls in the inactive white@50% state,
         matching the un-focused / no-selection iPhone snapshot). -->
    <div class="MarkdownEditor__toolbar">
      <!-- Heading menu: "H" + chevron.down -->
      <div class="MarkdownEditor__heading">
        <span class="MarkdownEditor__hLabel">H</span>
        <svg
          class="MarkdownEditor__chevron"
          viewBox="0 0 16 10"
          fill="none"
          stroke="currentColor"
          stroke-width="2.4"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
        >
          <path d="M2 2.5 8 8 14 2.5" />
        </svg>
      </div>

      <span class="MarkdownEditor__sep" aria-hidden="true"></span>

      <!-- list.bullet -->
      <span class="MarkdownEditor__btn" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
          <circle cx="4" cy="6" r="1.25" fill="currentColor" stroke="none" />
          <circle cx="4" cy="12" r="1.25" fill="currentColor" stroke="none" />
          <circle cx="4" cy="18" r="1.25" fill="currentColor" stroke="none" />
          <path d="M9 6h12M9 12h12M9 18h12" />
        </svg>
      </span>

      <!-- text.quote: two opening quote marks + three indented text lines -->
      <span class="MarkdownEditor__btn" aria-hidden="true">
        <svg viewBox="0 0 24 24">
          <g fill="currentColor" stroke="none">
            <path d="M2 6h3.4v3c0 1.6-.9 2.7-2.6 3.1l-.5-1.1c.9-.2 1.5-.7 1.6-1.4H2z" />
            <path d="M6.7 6h3.4v3c0 1.6-.9 2.7-2.6 3.1l-.5-1.1c.9-.2 1.5-.7 1.6-1.4H6.7z" />
          </g>
          <g fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
            <path d="M13 8h8M4 14h17M4 18h17" />
          </g>
        </svg>
      </span>

      <span class="MarkdownEditor__sep" aria-hidden="true"></span>

      <!-- bold -->
      <span class="MarkdownEditor__btn MarkdownEditor__btn--letter">
        <span class="MarkdownEditor__bold">B</span>
      </span>

      <!-- italic: serifed slanted I (SF Symbol "italic") -->
      <span class="MarkdownEditor__btn" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
          <path d="M10 5h7M7 19h7M15 5l-6 14" />
        </svg>
      </span>

      <span class="MarkdownEditor__sep" aria-hidden="true"></span>

      <!-- textformat.alt (clear formatting) -->
      <span class="MarkdownEditor__btn MarkdownEditor__btn--letter">
        <span class="MarkdownEditor__aa">Aa</span>
      </span>

      <span class="MarkdownEditor__sep" aria-hidden="true"></span>

      <!-- arrow.uturn.backward (undo) -->
      <span class="MarkdownEditor__btn" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M4 8h11a5 5 0 0 1 0 10H8" />
          <path d="M7.5 4.5 4 8l3.5 3.5" />
        </svg>
      </span>

      <!-- arrow.uturn.forward (redo) -->
      <span class="MarkdownEditor__btn" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M20 8H9a5 5 0 0 0 0 10h7" />
          <path d="M16.5 4.5 20 8l-3.5 3.5" />
        </svg>
      </span>
    </div>

    <div class="MarkdownEditor__divider" aria-hidden="true"></div>

    <!-- Editor area: placeholder (empty) or the flattened markdown lines. -->
    <div class="MarkdownEditor__editor">
      <!-- Interactive mode: a real auto-growing textarea over the raw source. -->
      <textarea
        v-if="props.interactive"
        class="MarkdownEditor__input"
        :placeholder="placeholder"
        :value="props.markdown"
        rows="1"
        @input="onInput"
      ></textarea>
      <template v-else>
        <div v-if="isEmpty" class="MarkdownEditor__placeholder">{{ placeholder }}</div>
        <div v-else class="MarkdownEditor__content">
          <div v-for="(line, i) in lines" :key="i" class="MarkdownEditor__line">{{ line || ' ' }}</div>
        </div>
      </template>
    </div>
  </div>
</template>
