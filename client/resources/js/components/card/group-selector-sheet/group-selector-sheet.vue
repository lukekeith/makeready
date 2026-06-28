<script lang="ts">
// GroupSelectorSheet — web twin of iOS Components/Display/GroupSelectorSheet.swift.
//
// A sheet-style picker: an inline navigation bar ("Select Group" + optional
// trailing close button) over a full-bleed appBackground canvas, followed by a
// vertical list of selectable group rows (name + "N members"). The currently
// selected row gets a white@0.1 rounded-12 background and a brandPrimary
// checkmark (checkmark.circle.fill) on the trailing edge.
//
// ⚠️ Parity note (compare snapshot): the iPhone GroupSelectorSheet is
// self-contained — it drives its list from an internal GroupFixtureManager
// @StateObject (hardcoded: Youth Group 12 / Sunday Service 45 / Bible Study 8 /
// Worship Team 15) and the ViewRegistry passes `selectedGroup: .constant(nil)`.
// So BOTH fixture variants (Default + NoneSelected) render the SAME hardcoded
// list with NO selection, ignoring the fixture's `groupList`/`selectedGroupName`.
// The trailing close button (a NavigationStack ToolbarItem) does NOT render in
// the SwiftUI ImageRenderer snapshot either — only the inline title does. To
// match the reference the adapter feeds that exact hardcoded list, no selection,
// and omits the close icon. The component itself stays fully data-driven (it can
// render any groupList, a selected row, and the close button when supplied).
//
// Fields (props):
//   groupList          { name, memberCount }[]  — rows to render (required)
//   selectedGroupName  string?  — name of the selected row (brand bg + checkmark)
//   title              string?  — nav title (default "Select Group")
//   closeIcon          string?  — inline SVG markup for the trailing close glyph
//                                  (xmark.circle.fill); omitted in the snapshot
</script>

<script setup lang="ts">
import { computed } from 'vue'

interface Group {
  name: string
  memberCount: number
}

interface Props {
  groupList: Group[]
  selectedGroupName?: string
  title?: string
  closeIcon?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  selectedGroupName: '',
  title: 'Select Group',
  closeIcon: '',
})

const memberLabel = (count: number) =>
  `${count} ${count === 1 ? 'member' : 'members'}`

const isSelected = (name: string) =>
  props.selectedGroupName != null && props.selectedGroupName === name

// checkmark.circle.fill — filled circle with a knocked-out check (the check is
// transparent so the brandPrimary fill reads as the iOS SF Symbol). Drawn via
// currentColor so the SCSS sets the brand purple.
const CHECK_SVG =
  '<svg viewBox="0 0 24 24" aria-hidden="true">' +
  '<path fill="currentColor" fill-rule="evenodd" clip-rule="evenodd" ' +
  'd="M12 23c6.075 0 11-4.925 11-11S18.075 1 12 1 1 5.925 1 12s4.925 11 11 11zm5.03-14.78a.75.75 0 0 1 0 1.06l-6.5 6.5a.75.75 0 0 1-1.06 0l-3-3a.75.75 0 1 1 1.06-1.06l2.47 2.47 5.97-5.97a.75.75 0 0 1 1.06 0z"/>' +
  '</svg>'
</script>

<template>
  <div class="GroupSelectorSheet" :class="props.class">
    <!-- Inline navigation bar: centered title + optional trailing close button -->
    <div class="GroupSelectorSheet__nav">
      <span class="GroupSelectorSheet__title">{{ props.title }}</span>
      <button
        v-if="props.closeIcon"
        type="button"
        class="GroupSelectorSheet__close"
        aria-label="Close"
        v-html="props.closeIcon"
      />
    </div>

    <!-- Group list -->
    <div class="GroupSelectorSheet__list">
      <div
        v-for="group in props.groupList"
        :key="group.name"
        class="GroupSelectorSheet__row"
        :class="{ 'GroupSelectorSheet__row--selected': isSelected(group.name) }"
        role="button"
        tabindex="0"
        :aria-pressed="isSelected(group.name) || undefined"
      >
        <div class="GroupSelectorSheet__rowText">
          <span class="GroupSelectorSheet__name">{{ group.name }}</span>
          <span class="GroupSelectorSheet__members">{{ memberLabel(group.memberCount) }}</span>
        </div>

        <span
          v-if="isSelected(group.name)"
          class="GroupSelectorSheet__check"
          aria-hidden="true"
          v-html="CHECK_SVG"
        />
      </div>
    </div>
  </div>
</template>
