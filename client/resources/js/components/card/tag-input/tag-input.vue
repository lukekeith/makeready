<script setup lang="ts">
// TagInput — twin of iOS Components/Input/TagInput.swift.
//
// A tag-entry field: a rounded white@5% well containing a flow-wrapped row of
// removable brand-purple tag pills (when any) above an inline text field that,
// in the captured variants, only ever shows its "Add tag..." placeholder.
//
// iOS layout (the card well):
//   VStack(spacing: 8) {
//     if !tags.isEmpty { FlowLayout(h:6, v:6) { TagPill … } }   // wrap pills
//     TextField(placeholder)  .font(s14).foregroundColor(.white)
//                             .frame(minHeight: 28, alignment: .leading)
//   }
//   .padding(.horizontal, 12).padding(.vertical, 8)
//   .background(Color.white.opacity(0.05)).cornerRadius(10)
//
//   TagPill = HStack(spacing: 4) {
//     Text(tag)  .font(s12Semibold).foregroundColor(.white)
//     xmark      .font(s8Bold).foregroundColor(.white.opacity(0.7))
//   } .padding(.horizontal, 8).padding(.vertical, 6)
//     .background(Capsule().fill(Color.brandPrimary))
//
// The snapshot only renders resting placeholder state (typed text / suggestions
// never appear), so the twin shows the placeholder gray (SwiftUI's TextField
// placeholder is the tertiary label ≈ white@30). Only the AI-suggestions affords
// are absent here (the harness never wires onRequestSuggestions).
//
// Fully data-driven via props; BEM mirrors
// resources/css/components/card/tag-input.scss.
interface Props {
  tags?: string[]
  placeholder?: string
}

withDefaults(defineProps<Props>(), {
  tags: () => [],
  placeholder: 'Add tag...',
})
</script>

<template>
  <div class="TagInputField">
    <div v-if="tags.length" class="TagInputField__tags">
      <span v-for="tag in tags" :key="tag" class="TagInputField__pill">
        <span class="TagInputField__pillText">{{ tag }}</span>
        <svg class="TagInputField__pillRemove" viewBox="0 0 12 12" fill="none" aria-hidden="true">
          <path d="M2.5 2.5 L9.5 9.5 M9.5 2.5 L2.5 9.5" stroke="currentColor"
                stroke-width="1.6" stroke-linecap="round" />
        </svg>
      </span>
    </div>

    <div class="TagInputField__input">{{ placeholder }}</div>
  </div>
</template>
