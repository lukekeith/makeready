<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'

interface Props {
  selected?: string
  avatarUrl?: string
  initials?: string
  homeHref?: string
  profileHref?: string
  memberName?: string
  memberPhone?: string
  memberEmail?: string
  memberFirstName?: string
  memberLastName?: string
  memberGender?: string
  memberBirthday?: string
  memberId?: string
  googleEmail?: string
  googlePicture?: string
  logoutUrl?: string
  csrfToken?: string
}

const props = withDefaults(defineProps<Props>(), {
  selected: 'home',
  initials: '?',
  homeHref: '/member/home',
  profileHref: '/member/profile',
})

// Modal state: null | 'menu' | 'account' | 'profile'
const activeModal = ref<string | null>(null)

// Profile form state
const firstName = ref(props.memberFirstName || '')
const lastName = ref(props.memberLastName || '')
const gender = ref(props.memberGender || '')
const birthday = ref(props.memberBirthday || '')
const isSaving = ref(false)
const saveError = ref('')

function openModal(modal: string) {
  activeModal.value = modal
  document.body.style.overflow = 'hidden'
}

function closeAll() {
  activeModal.value = null
  document.body.style.overflow = ''
}

function handleAvatarClick() {
  openModal('menu')
}

function handleKeyDown(e: KeyboardEvent) {
  if (e.key === 'Escape' && activeModal.value) {
    e.preventDefault()
    closeAll()
  }
}

onMounted(() => document.addEventListener('keydown', handleKeyDown))
onUnmounted(() => {
  document.removeEventListener('keydown', handleKeyDown)
  document.body.style.overflow = ''
})

function handleLogout() {
  if (!props.logoutUrl) return
  const form = document.createElement('form')
  form.method = 'POST'
  form.action = props.logoutUrl
  const token = document.createElement('input')
  token.type = 'hidden'
  token.name = '_token'
  token.value = props.csrfToken || document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content || ''
  form.appendChild(token)
  document.body.appendChild(form)
  form.submit()
}

function formatBirthdayForInput(val: string): string {
  if (!val) return ''
  // Handle ISO string
  const d = new Date(val)
  if (isNaN(d.getTime())) return val
  return d.toISOString().split('T')[0]
}

function formatBirthdayDisplay(val: string): string {
  if (!val) return ''
  const d = new Date(val)
  if (isNaN(d.getTime())) return val
  return `${String(d.getMonth() + 1).padStart(2, '0')}/${String(d.getDate()).padStart(2, '0')}/${d.getFullYear()}`
}

async function handleSaveProfile() {
  if (isSaving.value) return
  isSaving.value = true
  saveError.value = ''
  try {
    const csrfToken = props.csrfToken || document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content || ''
    const res = await fetch(props.profileHref, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-CSRF-TOKEN': csrfToken,
      },
      body: JSON.stringify({
        _method: 'POST',
        first_name: firstName.value,
        last_name: lastName.value,
        gender: gender.value,
        birthday: birthday.value,
      }),
    })
    if (res.ok || res.status === 302) {
      closeAll()
      window.location.reload()
    } else {
      const data = await res.json().catch(() => ({}))
      saveError.value = data.message || 'Failed to save profile'
    }
  } catch {
    saveError.value = 'Network error'
  } finally {
    isSaving.value = false
  }
}
</script>

<template>
  <nav class="Navigation">
    <!-- Home -->
    <a :href="homeHref" :class="['Navigation__button', selected === 'home' && 'Navigation__button--selected']" aria-label="home" :aria-current="selected === 'home' ? 'page' : undefined">
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M3 9.5L12 3L21 9.5V20C21 20.5304 20.7893 21.0391 20.4142 21.4142C20.0391 21.7893 19.5304 22 19 22H5C4.46957 22 3.96086 21.7893 3.58579 21.4142C3.21071 21.0391 3 20.5304 3 20V9.5Z" :fill="selected === 'home' ? 'white' : 'rgba(255, 255, 255, 0.7)'"/><path d="M9 22V12H15V22" :stroke="selected === 'home' ? '#252936' : 'rgba(37, 41, 54, 0.7)'" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
    </a>
    <!-- Schedule -->
    <a href="#" :class="['Navigation__button', selected === 'schedule' && 'Navigation__button--selected']" aria-label="schedule">
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none"><rect x="3" y="4" width="18" height="18" rx="2" :stroke="selected === 'schedule' ? 'white' : 'rgba(255, 255, 255, 0.7)'" stroke-width="2"/><path d="M3 10H21" :stroke="selected === 'schedule' ? 'white' : 'rgba(255, 255, 255, 0.7)'" stroke-width="2"/><path d="M8 2V6" :stroke="selected === 'schedule' ? 'white' : 'rgba(255, 255, 255, 0.7)'" stroke-width="2" stroke-linecap="round"/><path d="M16 2V6" :stroke="selected === 'schedule' ? 'white' : 'rgba(255, 255, 255, 0.7)'" stroke-width="2" stroke-linecap="round"/></svg>
    </a>
    <!-- Profile (avatar) -->
    <button type="button" :class="['Navigation__button', selected === 'profile' && 'Navigation__button--selected']" aria-label="profile" @click="handleAvatarClick">
      <span class="Avatar Navigation__avatar">
        <img v-if="avatarUrl" :src="avatarUrl" alt="Profile" class="Avatar__image" referrerpolicy="no-referrer" />
        <span v-else class="Avatar__fallback Navigation__avatar-fallback">{{ initials }}</span>
      </span>
    </button>
    <!-- Notes -->
    <a href="#" :class="['Navigation__button', selected === 'notes' && 'Navigation__button--selected']" aria-label="notes">
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M14 2H6C5.46957 2 4.96086 2.21071 4.58579 2.58579C4.21071 2.96086 4 3.46957 4 4V20C4 20.5304 4.21071 21.0391 4.58579 21.4142C4.96086 21.7893 5.46957 22 6 22H18C18.5304 22 19.0391 21.7893 19.4142 21.4142C19.7893 21.0391 20 20.5304 20 20V8L14 2Z" :stroke="selected === 'notes' ? 'white' : 'rgba(255, 255, 255, 0.7)'" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M14 2V8H20" :stroke="selected === 'notes' ? 'white' : 'rgba(255, 255, 255, 0.7)'" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M16 13H8" :stroke="selected === 'notes' ? 'white' : 'rgba(255, 255, 255, 0.7)'" stroke-width="2" stroke-linecap="round"/><path d="M16 17H8" :stroke="selected === 'notes' ? 'white' : 'rgba(255, 255, 255, 0.7)'" stroke-width="2" stroke-linecap="round"/></svg>
    </a>
    <!-- Search -->
    <a href="#" :class="['Navigation__button', selected === 'search' && 'Navigation__button--selected']" aria-label="search">
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none"><circle cx="11" cy="11" r="7" :stroke="selected === 'search' ? 'white' : 'rgba(255, 255, 255, 0.7)'" stroke-width="2"/><path d="M21 21L16.5 16.5" :stroke="selected === 'search' ? 'white' : 'rgba(255, 255, 255, 0.7)'" stroke-width="2" stroke-linecap="round"/></svg>
    </a>
  </nav>

  <!-- ═══ MODALS (teleported to body) ═══ -->
  <Teleport to="body">

    <!-- ─── Navigation Menu (bottom sheet) ─── -->
    <template v-if="activeModal === 'menu'">
      <div class="ModalProvider__overlay" style="z-index: 999" @click="closeAll" aria-hidden="true" />
      <div class="ModalProvider__modal ModalProvider__modal--menu" style="z-index: 1000" role="dialog" aria-modal="true">
        <div class="ModalProvider__menu-close-container">
          <button class="ModalProvider__close" @click="closeAll" aria-label="Close">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>
        <div class="ModalProvider__content">
          <div class="NavigationMenuContent">
            <a
              v-if="googleEmail"
              href="/admin"
              class="Button Button--secondary Button--size-default Button--mode-block"
            >
              <span class="Button__content">
                <span class="Button__icon Button__icon--left">
                  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <rect width="7" height="9" x="3" y="3" rx="1"/><rect width="7" height="5" x="14" y="3" rx="1"/>
                    <rect width="7" height="5" x="14" y="12" rx="1"/><rect width="7" height="9" x="3" y="12" rx="1"/>
                  </svg>
                </span>
                <span class="Button__label">Group Leader Admin</span>
              </span>
            </a>
            <button type="button" class="Button Button--secondary Button--size-default Button--mode-block" @click="openModal('profile')">
              <span class="Button__content">
                <span class="Button__icon Button__icon--left"><svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg></span>
                <span class="Button__label">Profile</span>
              </span>
            </button>
            <button type="button" class="Button Button--secondary Button--size-default Button--mode-block" @click="openModal('account')">
              <span class="Button__content">
                <span class="Button__icon Button__icon--left"><svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg></span>
                <span class="Button__label">Account</span>
              </span>
            </button>
            <div class="NavigationMenuContent__legal">
              <button type="button" class="Button Button--link-muted Button--size-default Button--mode-action" @click="closeAll(); window.location.href = '/pages/terms'">
                <span class="Button__content"><span class="Button__label">Terms of use</span></span>
              </button>
              <button type="button" class="Button Button--link-muted Button--size-default Button--mode-action" @click="closeAll(); window.location.href = '/pages/privacy'">
                <span class="Button__content"><span class="Button__label">Privacy policy</span></span>
              </button>
            </div>
            <button type="button" class="Button Button--destructive Button--size-default Button--mode-block" @click="handleLogout">
              <span class="Button__content">
                <span class="Button__icon Button__icon--left"><svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2 2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" x2="9" y1="12" y2="12"/></svg></span>
                <span class="Button__label">Logout</span>
              </span>
            </button>
          </div>
        </div>
      </div>
    </template>

    <!-- ─── Account Modal (fullscreen) ─── -->
    <template v-if="activeModal === 'account'">
      <div class="ModalProvider__overlay" style="z-index: 1001" @click="closeAll" aria-hidden="true" />
      <div class="ModalProvider__modal ModalProvider__modal--fullscreen" style="z-index: 1002" role="dialog" aria-modal="true">
        <div class="ModalProvider__close-container">
          <button class="ModalProvider__close" @click="closeAll" aria-label="Close">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>
          </button>
        </div>
        <div class="ModalProvider__content">
          <div class="AccountModalContent">
            <div class="PageTitle PageTitle--default AccountModalContent__header">
              <div class="PageTitle__container">
                <div class="PageTitle__left">
                  <button type="button" class="PageTitle__icon-button" @click="closeAll">
                    <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>
                  </button>
                </div>
                <div class="PageTitle__center"><span class="PageTitle__title">Account</span></div>
                <div class="PageTitle__right"></div>
              </div>
            </div>
            <div class="AccountModalContent__main">
              <div class="AccountModalContent__links">
                <!-- Member phone -->
                <div class="AccountLink AccountLink--linked-member">
                  <div class="AccountLink__content">
                    <p class="AccountLink__label">Member account phone</p>
                    <p class="AccountLink__phone">{{ memberPhone || '—' }}</p>
                  </div>
                </div>
                <!-- Google account (if linked) -->
                <div v-if="googleEmail" class="AccountLink AccountLink--linked-google">
                  <div class="AccountLink__content AccountLink__content--google">
                    <span class="Avatar AccountLink__avatar">
                      <img v-if="googlePicture" class="Avatar__image" :alt="memberName" :src="googlePicture" />
                      <span v-else class="Avatar__fallback">{{ initials }}</span>
                    </span>
                    <div class="AccountLink__details">
                      <p class="AccountLink__name">{{ memberName }}</p>
                      <p class="AccountLink__email">{{ googleEmail }}</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </template>

    <!-- ─── Edit Profile Modal (fullscreen) ─── -->
    <template v-if="activeModal === 'profile'">
      <div class="ModalProvider__overlay" style="z-index: 1001" @click="closeAll" aria-hidden="true" />
      <div class="ModalProvider__modal ModalProvider__modal--fullscreen" style="z-index: 1002" role="dialog" aria-modal="true">
        <div class="ModalProvider__content">
          <div class="EditProfileModalContent">
            <div class="PageTitle PageTitle--default EditProfileModalContent__header">
              <div class="PageTitle__container">
                <div class="PageTitle__left">
                  <button type="button" class="PageTitle__icon-button" @click="closeAll">
                    <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>
                  </button>
                </div>
                <div class="PageTitle__center"><span class="PageTitle__title">Edit profile</span></div>
                <div class="PageTitle__right">
                  <button type="button" class="PageTitle__link-button" :disabled="isSaving" @click="handleSaveProfile">
                    {{ isSaving ? 'Saving...' : 'Save' }}
                  </button>
                </div>
              </div>
            </div>
            <div class="EditProfileModalContent__content">
              <!-- Avatar -->
              <button type="button" class="EditProfileModalContent__avatar-button" aria-label="Change profile picture">
                <span class="Avatar EditProfileModalContent__avatar">
                  <img v-if="avatarUrl" class="Avatar__image" alt="Profile" :src="avatarUrl" />
                  <span v-else class="Avatar__fallback">{{ initials }}</span>
                </span>
              </button>
              <div class="EditProfileModalContent__avatar-actions"></div>

              <!-- Error -->
              <div v-if="saveError" style="color: #ef4444; text-align: center; font-size: 14px; padding: 8px 0;">{{ saveError }}</div>

              <!-- Profile Form -->
              <div class="ProfileForm ProfileForm--default">
                <div class="ProfileForm__fields">
                  <div :class="['MobileInput', 'MobileInput--size-default', firstName && 'MobileInput--floating']">
                    <div class="MobileInput__wrapper">
                      <label class="MobileInput__label">First name</label>
                      <input type="text" class="MobileInput__input" v-model="firstName" />
                    </div>
                  </div>
                  <div :class="['MobileInput', 'MobileInput--size-default', lastName && 'MobileInput--floating']">
                    <div class="MobileInput__wrapper">
                      <label class="MobileInput__label">Last name</label>
                      <input type="text" class="MobileInput__input" v-model="lastName" />
                    </div>
                  </div>
                  <div class="MobileSelect MobileSelect--size-default">
                    <label class="MobileSelect__label">Gender</label>
                    <div class="MobileSelect__wrapper">
                      <select class="MobileSelect__select" v-model="gender">
                        <option value="" disabled>Select gender</option>
                        <option value="male">Male</option>
                        <option value="female">Female</option>
                      </select>
                      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="MobileSelect__icon"><path d="m6 9 6 6 6-6"/></svg>
                    </div>
                  </div>
                  <div :class="['MobileDate', 'MobileDate--size-default', birthday && 'MobileDate--floating']">
                    <label class="MobileDate__label">Birthday</label>
                    <div class="MobileDate__wrapper">
                      <input type="date" class="MobileDate__picker" :max="new Date().toISOString().split('T')[0]" v-model="birthday" />
                      <input type="text" inputmode="numeric" class="MobileDate__input" placeholder="MM/DD/YYYY" :value="formatBirthdayDisplay(birthday)" readonly />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </template>

  </Teleport>
</template>
