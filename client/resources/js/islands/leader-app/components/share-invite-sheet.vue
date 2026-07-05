<script setup lang="ts">
// ShareInviteSheet — production rebuild of the iPhone ShareInviteSheet
// (Components/Display/ShareInviteSheet.swift): a full-screen sheet with an
// xmark / "Done" title row, a centered 320px server-generated QR code, and the
// bottom "Share QR Code" (native share) + "Copy Invite Link" actions.
//
// Flow (matches AddMenu.createInviteAndShowQR + the sheet's generateQRImage):
//   1. POST /api/invites            → invite code
//   2. POST /api/qrcode/generate    → display QR (640px, logo) — InviteQRCodeView
//   3. POST /api/qrcode/generate    → share QR (800px, no logo) — ShareLink payload
// The QR encodes https://www.makeready.org/join/{code}; "Copy Invite Link"
// copies that same URL.
import { ref, watch } from 'vue'
import { useLeaderLibrary } from '../stores/leader-library.store'

const props = defineProps<{ open: boolean }>()
const emit = defineEmits<{ close: [] }>()

const store = useLeaderLibrary()

const inviteCode = ref<string | null>(null)
const displayQr = ref<string | null>(null)
const shareQr = ref<string | null>(null)
const failed = ref(false)
const copied = ref(false)
let copyTimer: ReturnType<typeof setTimeout> | null = null

function inviteUrl(): string {
  return `https://www.makeready.org/join/${inviteCode.value ?? ''}`
}

watch(
  () => props.open,
  async (open) => {
    if (!open) return
    inviteCode.value = null
    displayQr.value = null
    shareQr.value = null
    failed.value = false
    copied.value = false
    try {
      inviteCode.value = await store.createInvite()
      const url = inviteUrl()
      // Display QR first (what the user sees), share payload in the background.
      displayQr.value = await store.generateQr(url, 640, true)
      shareQr.value = await store.generateQr(url, 800, false)
    } catch {
      failed.value = true
    }
  },
)

function copyLink(): void {
  if (!inviteCode.value) return
  navigator.clipboard?.writeText(inviteUrl())
  copied.value = true
  if (copyTimer) clearTimeout(copyTimer)
  copyTimer = setTimeout(() => {
    copied.value = false
  }, 2000)
}

// iOS ShareLink shares the QR image itself ("MakeReady Team Invite"); on the
// web we try the file share, then a URL share, then fall back to copying.
async function shareQrCode(): Promise<void> {
  const dataUrl = shareQr.value ?? displayQr.value
  try {
    if (dataUrl && navigator.share) {
      const blob = await (await fetch(dataUrl)).blob()
      const file = new File([blob], 'makeready-invite-qr.png', { type: blob.type || 'image/png' })
      if (!navigator.canShare || navigator.canShare({ files: [file] })) {
        await navigator.share({ files: [file], title: 'MakeReady Team Invite' })
        return
      }
    }
    if (navigator.share) {
      await navigator.share({ title: 'MakeReady Team Invite', url: inviteUrl() })
      return
    }
    copyLink()
  } catch {
    // Share cancelled or unsupported — nothing to surface (matches iOS, where
    // dismissing the share sheet is a no-op).
  }
}

const XMARK =
  '<svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M3 3l14 14M17 3L3 17"/></svg>'
const SHARE_UP =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 15V3"/><path d="M8 7l4-4 4 4"/><path d="M5 12v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6"/></svg>'
const LINK_ICON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7.5.5l3-3a5 5 0 0 0-7-7l-1.7 1.7"/><path d="M14 11a5 5 0 0 0-7.5-.5l-3 3a5 5 0 0 0 7 7l1.7-1.7"/></svg>'
const CHECKMARK =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12.5l5.5 5.5L20 6.5"/></svg>'
const WARNING =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3L1.8 20.5h20.4z"/><path d="M12 10v5"/><circle cx="12" cy="18" r="0.5" fill="currentColor"/></svg>'
</script>

<template>
  <Teleport to="body">
    <Transition name="ShareInviteSheet">
      <div v-if="open" class="ShareInviteSheet">
        <!-- PageTitle.iconLink: xmark left, "Done" link right (brandPrimary). -->
        <div class="ShareInviteSheet__titleBar">
          <button
            class="ShareInviteSheet__closeBtn"
            type="button"
            aria-label="Close"
            v-html="XMARK"
            @click="emit('close')"
          ></button>
          <button class="ShareInviteSheet__done" type="button" @click="emit('close')">Done</button>
        </div>

        <!-- Centered QR (iOS InviteQRCodeView: 320pt, spinner while generating). -->
        <div class="ShareInviteSheet__body">
          <div v-if="failed" class="ShareInviteSheet__error">
            <span class="ShareInviteSheet__errorIcon" v-html="WARNING"></span>
            <span>Failed to generate QR code</span>
          </div>
          <img
            v-else-if="displayQr"
            class="ShareInviteSheet__qr"
            :src="displayQr"
            alt="Invite QR code"
          />
          <span v-else class="ShareInviteSheet__spinner" aria-label="Generating QR code"></span>
        </div>

        <!-- Bottom actions. -->
        <div class="ShareInviteSheet__actions">
          <button
            v-if="displayQr && !failed"
            class="ShareInviteSheet__share"
            type="button"
            @click="shareQrCode"
          >
            <span class="ShareInviteSheet__btnIcon" v-html="SHARE_UP"></span>
            Share QR Code
          </button>
          <button
            class="ShareInviteSheet__copy"
            type="button"
            :disabled="!inviteCode"
            @click="copyLink"
          >
            <span class="ShareInviteSheet__btnIcon" v-html="copied ? CHECKMARK : LINK_ICON"></span>
            {{ copied ? 'Copied!' : 'Copy Invite Link' }}
          </button>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
/* Full-screen sheet clipped to the 480px phone column. */
.ShareInviteSheet {
  position: fixed;
  top: 0;
  bottom: 0;
  left: 50%;
  transform: translateX(-50%);
  width: 100%;
  max-width: 480px;
  z-index: 50;
  display: flex;
  flex-direction: column;
  background: var(--color-canvas);
  color: #fff;
  transition: transform 0.3s ease, opacity 0.3s ease;
}

.ShareInviteSheet-enter-from,
.ShareInviteSheet-leave-to {
  opacity: 0;
  transform: translateX(-50%) translateY(24px);
}

.ShareInviteSheet__titleBar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 53px;
  padding: 0 16px;
}

.ShareInviteSheet__closeBtn {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: none;
  background: none;
  color: #fff;
  cursor: pointer;
  padding: 0;
}

.ShareInviteSheet__closeBtn :deep(svg) {
  width: 17px;
  height: 17px;
  display: block;
}

.ShareInviteSheet__done {
  border: none;
  background: none;
  padding: 0;
  font-size: 17px;
  font-weight: 600;
  color: var(--color-brand-500);
  cursor: pointer;
}

.ShareInviteSheet__body {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
}

.ShareInviteSheet__qr {
  width: 320px;
  height: 320px;
  max-width: calc(100% - 48px);
  border-radius: 12px;
}

/* Spoke spinner (iOS ProgressView) while the server generates the code. */
.ShareInviteSheet__spinner {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  border: 3px solid var(--color-white-10);
  border-top-color: var(--color-white-50);
  animation: ShareInviteSheet-spin 0.8s linear infinite;
}

@keyframes ShareInviteSheet-spin {
  to {
    transform: rotate(360deg);
  }
}

.ShareInviteSheet__error {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  color: var(--color-white-50);
  font-size: 15px;
}

.ShareInviteSheet__errorIcon {
  width: 40px;
  height: 40px;
  color: var(--color-white-30);
}

.ShareInviteSheet__errorIcon :deep(svg) {
  width: 100%;
  height: 100%;
}

.ShareInviteSheet__actions {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 0 24px 40px;
}

.ShareInviteSheet__share,
.ShareInviteSheet__copy {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  width: 100%;
  padding: 16px 0;
  border: none;
  border-radius: 12px;
  font-size: 17px;
  font-weight: 700;
  cursor: pointer;
}

.ShareInviteSheet__share {
  background: var(--color-brand-500);
  color: #fff;
}

.ShareInviteSheet__copy {
  background: var(--color-white-10);
  color: var(--color-brand-500);
}

.ShareInviteSheet__copy:disabled {
  opacity: 0.5;
  cursor: default;
}

.ShareInviteSheet__btnIcon {
  display: inline-flex;
  width: 20px;
  height: 20px;
}

.ShareInviteSheet__btnIcon :deep(svg) {
  width: 100%;
  height: 100%;
  display: block;
}
</style>
