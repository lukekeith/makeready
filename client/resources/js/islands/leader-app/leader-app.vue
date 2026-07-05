<script setup lang="ts">
// LeaderApp — root shell for the mobile-web leader experience at /admin.
// A phone-width column: the routed view scrolls, the bottom NavBar (reused twin)
// stays pinned and drives tab navigation. Mirrors the iPhone MainView.
import { computed, onMounted, provide } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from 'axios'
import NavBar from '../../components/card/nav-bar/nav-bar.vue'
import OverlayHost from './overlay/overlay-host.vue'
import ConfirmDialogHost from './overlay/confirm-dialog-host.vue'

interface Props {
  avatarUrl?: string | null
  initials?: string
  memberName?: string
  googleEmail?: string | null
  logoutUrl?: string
  memberId?: string | null
}

const props = withDefaults(defineProps<Props>(), {
  initials: '?',
  memberName: 'Leader',
})

provide('memberId', props.memberId)
provide('memberName', props.memberName)
provide('avatarUrl', props.avatarUrl)
provide('googleEmail', props.googleEmail)
provide('logoutUrl', props.logoutUrl)

const route = useRoute()
const router = useRouter()

type NavTab = 'home' | 'groups' | 'library' | 'calendar' | 'search' | 'profile'
const TAB_PATHS: Record<NavTab, string> = {
  home: '/admin',
  groups: '/admin/groups',
  library: '/admin/library',
  calendar: '/admin/calendar',
  search: '/admin/search',
  profile: '/admin/profile',
}

const activeTab = computed<NavTab>(() => (route.meta.tab as NavTab) ?? 'home')

function selectTab(tab: NavTab): void {
  const path = TAB_PATHS[tab]
  if (path && route.path !== path) router.push(path)
}

onMounted(() => {
  const token = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content
  if (token) axios.defaults.headers.common['X-CSRF-TOKEN'] = token
})
</script>

<template>
  <div class="LeaderApp">
    <main class="LeaderApp__view">
      <RouterView />
    </main>
    <NavBar
      class="LeaderApp__nav"
      :active-tab="activeTab"
      :avatar-url="avatarUrl"
      :avatar-initials="initials"
      @select="selectTab"
    />
    <OverlayHost />
    <ConfirmDialogHost />
  </div>
</template>

<style scoped>
.LeaderApp {
  /* Heights of the fixed nav elements. Views set their sticky top header to
     --header-height; the scroll content pads the bottom by --footer-height so it
     clears the frosted nav while still scrolling underneath it (iOS MainView). */
  --header-height: 71px; /* PageHeader tab row */
  --footer-height: 106px; /* NavBar (icon + label + iOS bottom safe-area pad) */

  position: relative; /* containing block for the fixed bottom nav */
  width: 100%;
  max-width: 480px;
  margin: 0 auto;
  height: 100dvh;
  background: var(--color-canvas);
  color: #fff;
  font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'SF Pro', sans-serif;
  overflow: hidden;
}

/* The scroll area fills the whole device column; content scrolls under both the
   sticky top header and the fixed bottom nav. Pad the bottom so the last items
   clear the nav (the top is offset by the view's own sticky header). */
.LeaderApp__view {
  position: absolute;
  inset: 0;
  overflow-y: auto;
  -webkit-overflow-scrolling: touch;
  padding-bottom: var(--footer-height);
}

/* Fixed frosted bottom nav: dark canvas @ 50% over a 20px backdrop blur. The
   shared NavBar twin stays transparent (compare parity); the frost lives here. */
.LeaderApp__nav {
  position: absolute;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 10;
  background: var(--surface-nav);
  backdrop-filter: blur(var(--blur-lg));
  -webkit-backdrop-filter: blur(var(--blur-lg));
}
</style>
