import './bootstrap'
import 'primeicons/primeicons.css'
import { createApp } from 'vue'
import { createPinia } from 'pinia'
import PrimeVue from 'primevue/config'
import ConfirmationService from 'primevue/confirmationservice'
import ToastService from 'primevue/toastservice'
import Aura from '@primevue/themes/aura'

// Admin island and router
import AdminIsland from './islands/admin-island/admin-island.vue'
import { router as adminRouter } from './islands/admin-island/router'

// Interactive Vue components (require client-side JS)
import PhoneEntry from './components/domain/phone-entry/phone-entry.vue'
import VideoPlayer from './components/domain/video-player/video-player.vue'
import Digit from './components/primitive/digit/digit.vue'
import Modal from './components/primitive/modal/modal.vue'
import VerifyCode from './components/primitive/verify-code/verify-code.vue'
import BulletTextInput from './components/primitive/bullet-text-input/bullet-text-input.vue'
import ModalProvider from './components/layout/modal-provider/modal-provider.vue'
import Keypad from './components/panel/keypad/keypad.vue'
import JoinPhoneIsland from './components/domain/join-phone-island/join-phone-island.vue'
import JoinVerifyIsland from './components/domain/join-verify-island/join-verify-island.vue'
import LessonIsland from './components/domain/lesson-island/lesson-island.vue'
import JoinCodeIsland from './components/domain/join-code-island/join-code-island.vue'
import LoginVerifyIsland from './components/domain/login-verify-island/login-verify-island.vue'
import NavigationIsland from './components/domain/navigation-island/navigation-island.vue'
import StudyHomeIsland from './components/domain/study-home-island/study-home-island.vue'
import HomeProfileButton from './components/domain/home-profile-button/home-profile-button.vue'
import GroupHeaderIsland from './components/domain/group-header-island/group-header-island.vue'
import MemberStudiesIsland from './components/domain/member-studies-island/member-studies-island.vue'
import SlidesIsland from './islands/slides-island/slides-island.vue'
import ComponentCapture from './components/domain/component-capture/component-capture.vue'

const componentRegistry = {
  'AdminIsland': AdminIsland,
  'ComponentCapture': ComponentCapture,
  'PhoneEntry': PhoneEntry,
  'VideoPlayer': VideoPlayer,
  'Digit': Digit,
  'Modal': Modal,
  'VerifyCode': VerifyCode,
  'BulletTextInput': BulletTextInput,
  'ModalProvider': ModalProvider,
  'Keypad': Keypad,
  'JoinPhoneIsland': JoinPhoneIsland,
  'JoinVerifyIsland': JoinVerifyIsland,
  'LessonIsland': LessonIsland,
  'JoinCodeIsland': JoinCodeIsland,
  'LoginVerifyIsland': LoginVerifyIsland,
  'NavigationIsland': NavigationIsland,
  'StudyHomeIsland': StudyHomeIsland,
  'HomeProfileButton': HomeProfileButton,
  'GroupHeaderIsland': GroupHeaderIsland,
  'MemberStudiesIsland': MemberStudiesIsland,
  'SlidesIsland': SlidesIsland,
}

// Vue island auto-mounter
// Usage in Blade: <div data-vue="PhoneEntry" data-props='{"title":"Enter your phone"}'></div>
document.querySelectorAll('[data-vue]').forEach((el) => {
  const name = el.dataset.vue
  const Component = componentRegistry[name]
  if (!Component) {
    console.warn(`[Vue islands] No component registered for "${name}"`)
    return
  }
  const props = el.dataset.props ? JSON.parse(el.dataset.props) : {}
  const app = createApp(Component, props)
  app.use(createPinia())
  if (name === 'AdminIsland') {
    app.use(adminRouter)
    app.use(PrimeVue, {
      theme: {
        preset: Aura,
        options: {
          darkModeSelector: false,
        },
      },
    })
    app.use(ConfirmationService)
    app.use(ToastService)
  }
  app.mount(el)
})
