import { createRouter, createWebHistory } from 'vue-router'
import DashboardSection from './sections/dashboard-section.vue'
import GroupsSection from './sections/groups-section.vue'
import MembersSection from './sections/members-section.vue'
import ProgramsSection from './sections/programs-section.vue'
import ProfileSection from './sections/profile-section.vue'
import LogsSection from './sections/logs-section.vue'

// Parked legacy admin SPA — served at /admin-legacy (the new mobile leader app
// owns /admin). Paths must match the Laravel /admin-legacy/{any?} catch-all.
export const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/admin-legacy',
      component: DashboardSection,
    },
    {
      path: '/admin-legacy/groups',
      component: GroupsSection,
    },
    {
      path: '/admin-legacy/groups/:id',
      component: GroupsSection,
    },
    {
      path: '/admin-legacy/programs',
      component: ProgramsSection,
    },
    {
      path: '/admin-legacy/programs/:id',
      component: ProgramsSection,
    },
    {
      path: '/admin-legacy/members',
      component: MembersSection,
    },
    {
      path: '/admin-legacy/profile',
      component: ProfileSection,
    },
    {
      path: '/admin-legacy/logs',
      component: LogsSection,
    },
    {
      path: '/admin-legacy/:pathMatch(.*)*',
      redirect: '/admin-legacy',
    },
  ],
})
