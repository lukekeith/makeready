import { createRouter, createWebHistory } from 'vue-router'
import DashboardSection from './sections/dashboard-section.vue'
import GroupsSection from './sections/groups-section.vue'
import MembersSection from './sections/members-section.vue'
import ProgramsSection from './sections/programs-section.vue'
import ProfileSection from './sections/profile-section.vue'
import LogsSection from './sections/logs-section.vue'

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/admin',
      component: DashboardSection,
    },
    {
      path: '/admin/groups',
      component: GroupsSection,
    },
    {
      path: '/admin/groups/:id',
      component: GroupsSection,
    },
    {
      path: '/admin/programs',
      component: ProgramsSection,
    },
    {
      path: '/admin/programs/:id',
      component: ProgramsSection,
    },
    {
      path: '/admin/members',
      component: MembersSection,
    },
    {
      path: '/admin/profile',
      component: ProfileSection,
    },
    {
      path: '/admin/logs',
      component: LogsSection,
    },
    {
      path: '/admin/:pathMatch(.*)*',
      redirect: '/admin',
    },
  ],
})
