<script setup lang="ts">
// RichTextInput — twin of iOS Components/Input/RichTextInput.swift.
//
// A native rich-text editor card: a fixed formatting toolbar (cardBackground),
// a hairline divider, and a tall (minHeight 200) editor area (backgroundDark).
// The toolbar is constant chrome — bold · italic · underline | AA▾ (heading
// menu) | undo · redo — so it is baked into this component; only the
// placeholder and the rendered text change between variants.
//
// KEY PARITY FACT (see the captured iPhone references): the iOS body uses a
// TextEditor whose `.font(Typography.s17).foregroundStyle(.white)` flattens the
// AttributedString produced by `htmlToAttributed()`. So in the isolated snapshot
// the HTML `<h1>`/`<p>` block tags split into separate LINES, but there is NO
// heading sizing, bold, italic, or underline styling — every block renders as
// flat 17pt white body text. This mirrors the MarkdownEditor twin's behaviour.
// So this twin parses block-level tags into lines, strips all remaining tags,
// and renders each line as plain 17pt white text rather than a "real" HTML
// renderer.
//
// Fully data-driven via props; BEM mirrors
// resources/css/components/card/rich-text-input.scss.
import { computed } from 'vue'

interface Props {
  placeholder?: string
  html?: string
}

const props = withDefaults(defineProps<Props>(), {
  placeholder: '',
  html: '',
})

const isEmpty = computed(() => (props.html ?? '').trim().length === 0)

// Decode the handful of HTML entities the iOS NSAttributedString parser resolves.
function decodeEntities(s: string): string {
  return s
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
}

// Flatten the HTML into plain lines: block tags become line breaks, every other
// tag (inline <b>/<i>/<u>/<span>) is stripped — matching the flat snapshot.
const lines = computed(() => {
  let h = props.html ?? ''
  // Block boundaries → newline.
  h = h.replace(/<\/(h[1-6]|p|div|li|blockquote)\s*>/gi, '\n')
  h = h.replace(/<br\s*\/?>/gi, '\n')
  // Strip every remaining tag.
  h = h.replace(/<[^>]+>/g, '')
  h = decodeEntities(h)
  const split = h.split('\n')
  // Trim leading/trailing blank lines but preserve interior blanks (block gaps).
  while (split.length && split[0].trim() === '') split.shift()
  while (split.length && split[split.length - 1].trim() === '') split.pop()
  return split
})
</script>

<template>
  <div class="RichTextInput">
    <!-- Toolbar (constant chrome, all controls in the inactive white@50% state,
         matching the un-focused / no-selection iPhone snapshot). -->
    <div class="RichTextInput__toolbar">
      <!-- bold -->
      <span class="RichTextInput__btn RichTextInput__btn--letter">
        <span class="RichTextInput__bold">B</span>
      </span>

      <!-- italic: serifed slanted I (SF Symbol "italic") -->
      <span class="RichTextInput__btn" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
          <path d="M10 5h7M7 19h7M15 5l-6 14" />
        </svg>
      </span>

      <!-- underline: U with a baseline rule (SF Symbol "underline") -->
      <span class="RichTextInput__btn" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
          <path d="M6 4v7a6 6 0 0 0 12 0V4" />
          <path d="M5 20h14" />
        </svg>
      </span>

      <span class="RichTextInput__sep" aria-hidden="true"></span>

      <!-- heading menu: textformat.size ("Aa" small→large) + chevron.down -->
      <div class="RichTextInput__heading">
        <span class="RichTextInput__aa">
          <span class="RichTextInput__aaSmall">A</span><span class="RichTextInput__aaLarge">A</span>
        </span>
        <svg
          class="RichTextInput__chevron"
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

      <span class="RichTextInput__sep" aria-hidden="true"></span>

      <!-- arrow.uturn.backward (undo) -->
      <span class="RichTextInput__btn" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M4 8h11a5 5 0 0 1 0 10H8" />
          <path d="M7.5 4.5 4 8l3.5 3.5" />
        </svg>
      </span>

      <!-- arrow.uturn.forward (redo) -->
      <span class="RichTextInput__btn" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M20 8H9a5 5 0 0 0 0 10h7" />
          <path d="M16.5 4.5 20 8l-3.5 3.5" />
        </svg>
      </span>
    </div>

    <div class="RichTextInput__divider" aria-hidden="true"></div>

    <!-- Editor area: placeholder (empty) or the flattened HTML lines. -->
    <div class="RichTextInput__editor">
      <div v-if="isEmpty" class="RichTextInput__placeholder">{{ placeholder }}</div>
      <div v-else class="RichTextInput__content">
        <div v-for="(line, i) in lines" :key="i" class="RichTextInput__line">{{ line || ' ' }}</div>
      </div>
    </div>
  </div>
</template>
