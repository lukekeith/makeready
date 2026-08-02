<script setup lang="ts">
// SearchView — production host of the LeaderApp Search tab (iOS
// Pages/Search/GlobalSearchPage.swift). Renders the shared GlobalSearch twin
// interactively and owns the data + presentation:
//
//   • recents load once on mount (iOS .onAppear, never refreshed)
//   • typing drives a 300ms debounced /api/search with a 2-char minimum
//   • filter badges collapse the list to one category (re-tap clears)
//   • result taps present the same destinations iOS does
//
// iOS opens nine destinations; the four that are their own detail pages
// (lesson / video / post / event — the `searchLesson`, `searchVideo`,
// `searchPost`, `searchEvent` string-keyed modals) are the NEXT queue item
// (search-detail-pages), so their rows are inert here. Templates are a no-op
// on iOS too, and `.notification` is unreachable there.
import { computed, onMounted } from 'vue'
import GlobalSearch from '../../../components/card/global-search/global-search.vue'
import ProgramHomeModal from '../components/program-home-modal.vue'
import GroupHomeModal from '../components/group-home-modal.vue'
import MemberProfileModal from '../components/member-profile-modal.vue'
import EnrollmentScheduleModal from '../components/enrollment-schedule-modal.vue'
import { ROUTES } from '../overlay/overlay-routes'
import { useOverlayManager } from '../overlay/overlay.store'
import { useLeaderSearch } from '../stores/leader-search.store'

const store = useLeaderSearch()
const overlayManager = useOverlayManager()

onMounted(() => {
  void store.loadRecents()
})

// iOS shows recents while the query is under 2 characters.
const sections = computed(() =>
  store.query.trim().length < 2 ? store.recents : store.sections
)

function rowTitle(category: string, id: string): string {
  const section = sections.value.find((s) => s.category === category)
  return section?.rows.find((r) => r.id === id)?.title ?? ''
}

function onSelectRow({ category, id }: { category: string; id: string }): void {
  switch (category) {
    case 'program':
      overlayManager.present(ROUTES.programHome, ProgramHomeModal, { programId: id })
      break
    case 'group':
      overlayManager.present(ROUTES.groupHome, GroupHomeModal, { groupId: id })
      break
    case 'member':
      // iOS seeds the profile with the row's title while it loads.
      overlayManager.present(ROUTES.memberProfile, MemberProfileModal, {
        memberId: id,
        seedName: rowTitle(category, id),
      })
      break
    case 'enrollment':
      overlayManager.present(ROUTES.enrollmentSchedule, EnrollmentScheduleModal, {
        enrollmentId: id,
        titleOverride: 'Lessons',
      })
      break
    default:
      // lesson / video / post / event → search-detail-pages queue item;
      // template is a deliberate no-op on iOS as well.
      break
  }
}
</script>

<template>
  <GlobalSearch
    interactive
    class="SearchView"
    :search-text="store.query"
    :active="store.query.length > 0"
    :sections="sections"
    :loading="store.loading"
    :active-category="store.activeCategory"
    @update:search-text="store.search($event)"
    @clear="store.clear()"
    @select-category="store.selectCategory($event)"
    @select-row="onSelectRow"
  />
</template>

<style scoped>
/* The shell's view slot is a padded scroll container; the search screen owns
   its own scrolling, so it fills the slot's padding box instead. */
.SearchView {
  position: absolute;
  inset: 0;
  height: auto;
}

/* Keep the last rows clear of the fixed NavBar (iOS scrolls under it). */
.SearchView :deep(.GlobalSearch__scroll) {
  padding-bottom: var(--footer-height);
}
</style>
