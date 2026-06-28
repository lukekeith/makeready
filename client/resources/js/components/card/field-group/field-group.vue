<script setup lang="ts">
// FieldGroup — twin of iOS Components/Input/FieldGroup.swift.
//
// A rounded white@5% container (the FieldGroup card) holding a vertical stack of
// rows. Each row is a leading-aligned label with full padding; rows are separated
// by a hairline white@10% divider. An optional trailing description row (smaller,
// white@70% text) is added below a final divider.
//
// iOS layout (as rendered by ViewRegistry `component.FieldGroup`):
//   FieldGroup {                          → VStack(spacing:0)
//                                            .padding(.vertical, 4)
//                                            .background(white@0.05)
//                                            .cornerRadius(10)
//     ForEach(rows) { row in
//       Text(row).font(s17).foregroundColor(.white)
//         .frame(maxWidth:.infinity, alignment:.leading).padding()   // 16 all sides
//       if !last { FieldGroupDivider() }                              // white@0.1, 1px
//     }
//     if description { FieldGroupDivider(); FieldGroupDescription(...) }
//   }.padding(16)                          → supplied by the harness .capture-wrap
//
// FieldGroupDescription: Text(text).font(s13).foregroundColor(.white@0.7)
//   .frame(maxWidth:.infinity, alignment:.leading)
//   .padding(.horizontal, 16).padding(.vertical, 12)
//
// Fully data-driven: pass the row labels via `fieldRows` and an optional
// `description`. BEM modifiers mirror resources/css/components/card/field-group.scss.
interface Props {
  fieldRows?: string[]
  description?: string
}

withDefaults(defineProps<Props>(), {
  fieldRows: () => [],
  description: '',
})
</script>

<template>
  <div class="FieldGroup">
    <template v-for="(row, idx) in fieldRows" :key="idx">
      <div class="FieldGroup__row">{{ row }}</div>
      <div
        v-if="idx < fieldRows.length - 1 || description"
        class="FieldGroup__divider"
        aria-hidden="true"
      ></div>
    </template>
    <div v-if="description" class="FieldGroup__description">{{ description }}</div>
  </div>
</template>
