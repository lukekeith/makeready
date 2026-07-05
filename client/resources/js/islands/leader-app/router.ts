import { createRouter, createWebHistory } from 'vue-router'
import DashboardView from './views/dashboard-view.vue'
import GroupsView from './views/groups-view.vue'
import LibraryView from './views/library-view.vue'
import ComingSoonView from './views/coming-soon-view.vue'

// Mobile leader app routes. Paths live under /admin (the Laravel /admin/{any?}
// catch-all serves this island). The dashboard is the Home tab; the other tabs
// are stubbed for now.
export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/admin', component: DashboardView, meta: { tab: 'home' } },
    // Groups page — each tab is its own route so it's deep-linkable / refreshable.
    { path: '/admin/groups', redirect: '/admin/groups/list' },
    { path: '/admin/groups/list', component: GroupsView, meta: { tab: 'groups', title: 'Groups', groupsTab: 'list' } },
    { path: '/admin/groups/members', component: GroupsView, meta: { tab: 'groups', title: 'Members', groupsTab: 'members' } },
    { path: '/admin/groups/enrolled', component: GroupsView, meta: { tab: 'groups', title: 'Enrolled', groupsTab: 'enrolled' } },
    // Library page — each tab is its own route so it's deep-linkable / refreshable.
    { path: '/admin/library', redirect: '/admin/library/programs' },
    { path: '/admin/library/programs', component: LibraryView, meta: { tab: 'library', title: 'Programs', libraryTab: 'programs' } },
    { path: '/admin/library/media', component: LibraryView, meta: { tab: 'library', title: 'Media', libraryTab: 'media' } },
    { path: '/admin/calendar', component: ComingSoonView, meta: { tab: 'calendar', title: 'Calendar' } },
    { path: '/admin/search', component: ComingSoonView, meta: { tab: 'search', title: 'Search' } },
    { path: '/admin/profile', component: ComingSoonView, meta: { tab: 'profile', title: 'Profile' } },
    { path: '/admin/:pathMatch(.*)*', redirect: '/admin' },
  ],
})
