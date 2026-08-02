import { ref } from 'vue'
import { defineStore } from 'pinia'
import axios from 'axios'
import type { MemberProfileGroup } from '../../../components/card/member-profile/member-profile.vue'

// Live data for the .memberProfile overlay (iPhone MemberProfilePage.swift),
// fetched through the shared /admin/api/* proxy:
//   • Profile → GET /api/members/:memberId/profile (GroupActions.loadMemberProfile)
// Formatting ports the iOS helpers verbatim:
//   • formatPhoneNumber (MemberProfilePage.swift:493-502) — 11-digit US only
//   • relativeDuration  (MemberProfilePage.swift:349-358) — 365d yr / 30d mo
//   • age               (GroupModels.swift:226-229)       — whole calendar years
//   • earliestJoinDate  (GroupModels.swift:232-234)       — min groups[].joinedAt
// Membership mutations (remove/rejoin/transfer) belong to the change-membership
// queue item and are NOT implemented here.

interface ApiProfileGroup {
  id: string
  name: string
  coverImageUrl?: string | null
  role?: string
  joinedAt?: string
}

interface ApiProfile {
  id: string
  firstName?: string | null
  lastName?: string | null
  phoneNumber?: string
  email?: string | null
  birthday?: string | null
  profilePicture?: string | null
  googleEmail?: string | null
  googlePicture?: string | null
  groups?: ApiProfileGroup[]
}

// iOS MemberProfilePage.formatPhoneNumber: only 11-digit "1…" numbers get the
// dot format; everything else passes through unchanged.
export function formatPhoneNumber(phone: string): string {
  const digits = phone.replace(/\D/g, '')
  if (digits.length !== 11 || !digits.startsWith('1')) return phone
  return `${digits.slice(1, 4)}.${digits.slice(4, 7)}.${digits.slice(7)}`
}

// iOS MemberProfilePage.relativeDuration: 365-day years, 30-day months,
// integer truncation, future dates clamp to "today".
export function relativeDuration(since: Date, now: Date = new Date()): string {
  const seconds = Math.max(0, (now.getTime() - since.getTime()) / 1000)
  const day = 86_400
  const year = 365 * day
  const month = 30 * day
  if (seconds >= year) {
    const y = Math.floor(seconds / year)
    return `${y}yr${y === 1 ? '' : 's'}`
  }
  if (seconds >= month) return `${Math.floor(seconds / month)}mo`
  if (seconds >= day) return `${Math.floor(seconds / day)}d`
  return 'today'
}

// iOS Calendar.dateComponents([.year]) — whole years elapsed.
export function wholeYearsSince(birthday: Date, now: Date = new Date()): number {
  let years = now.getFullYear() - birthday.getFullYear()
  const anniversary = new Date(birthday)
  anniversary.setFullYear(birthday.getFullYear() + years)
  if (anniversary.getTime() > now.getTime()) years -= 1
  return years
}

// iOS DateFormatters.monthDayYear ("MMM d, yyyy").
function monthDayYear(d: Date): string {
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
}

// iOS DateFormatters.mediumDateShortTime → "Jun 30, 2026 at 7:30 AM".
function mediumDateShortTime(d: Date): string {
  const date = d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
  const time = d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
  return `${date} at ${time}`
}

export const useLeaderMember = defineStore('leader-member', () => {
  const loading = ref(false)
  const error = ref<string | null>(null)
  const loaded = ref(false)

  // Display-ready fields (the twin renders these verbatim).
  const displayName = ref('')
  const avatarUrl = ref('')
  const joined = ref('')
  const age = ref('')
  const phone = ref<string | undefined>(undefined)
  // Unformatted number for sms:/tel: URLs (iOS dials profile.phoneNumber raw).
  const rawPhone = ref('')
  const email = ref('')
  const groups = ref<MemberProfileGroup[]>([])
  // Canonical member id (iOS: profile?.id ?? memberId — the param may be a
  // user id; mutations in later queue items must use this).
  const memberRecordId = ref('')

  function reset(seedName: string, seedAvatarUrl: string): void {
    loading.value = false
    error.value = null
    loaded.value = false
    displayName.value = seedName
    avatarUrl.value = seedAvatarUrl
    joined.value = ''
    age.value = ''
    phone.value = undefined
    email.value = ''
    groups.value = []
    memberRecordId.value = ''
  }

  // iOS loadProfile: error only assigned when no profile is loaded; the seeded
  // hero stays up while loading (no blocking spinner from seeded entries).
  async function loadMemberProfile(memberId: string): Promise<void> {
    loading.value = !loaded.value && !displayName.value && !avatarUrl.value
    error.value = null
    try {
      const res = await axios.get(`/admin/api/members/${memberId}/profile`)
      const p: ApiProfile | undefined = res.data?.data
      if (!res.data?.success || !p) {
        throw new Error(res.data?.error || 'Failed to load member profile')
      }
      memberRecordId.value = p.id
      displayName.value = [p.firstName, p.lastName].filter(Boolean).join(' ')
      avatarUrl.value = p.profilePicture ?? p.googlePicture ?? ''

      const joinDates = (p.groups ?? [])
        .map((g) => (g.joinedAt ? new Date(g.joinedAt) : null))
        .filter((d): d is Date => !!d && !Number.isNaN(d.getTime()))
      joined.value = joinDates.length
        ? monthDayYear(new Date(Math.min(...joinDates.map((d) => d.getTime()))))
        : ''

      if (p.birthday) {
        const b = new Date(p.birthday)
        age.value = Number.isNaN(b.getTime()) ? '' : String(wholeYearsSince(b))
      } else {
        age.value = ''
      }

      // iOS dataItems: Phone ALWAYS renders once loaded (even empty).
      rawPhone.value = p.phoneNumber ?? ''
      phone.value = formatPhoneNumber(p.phoneNumber ?? '')
      email.value = p.email ?? p.googleEmail ?? ''

      // iOS memberCards: server order preserved, no filtering/sorting. All
      // cards are "Joined" here — removedAt only appears via the (later)
      // change-membership mutations.
      groups.value = (p.groups ?? []).map((g) => {
        const joinedAt = g.joinedAt ? new Date(g.joinedAt) : null
        const valid = joinedAt && !Number.isNaN(joinedAt.getTime())
        return {
          id: g.id,
          name: g.name,
          imageUrl: g.coverImageUrl || undefined,
          number: valid ? relativeDuration(joinedAt) : 'today',
          dateLabel: valid ? `Joined ${mediumDateShortTime(joinedAt)}` : 'Joined',
          removed: false,
        }
      })
      loaded.value = true
    } catch (e) {
      // iOS: warm background-refresh failures are swallowed; error only when
      // nothing is loaded.
      if (!loaded.value) {
        error.value =
          (axios.isAxiosError(e) && (e.response?.data as { error?: string })?.error) ||
          (e instanceof Error ? e.message : 'Failed to load member profile')
      }
    } finally {
      loading.value = false
    }
  }

  // ── Change-membership mutations (iOS GroupActions via the modal's
  // presenter callbacks — MemberProfilePage does NO refetch; the Actions flip
  // the group cards directly and the page re-renders). All calls use the
  // canonical memberRecordId (iOS: profile?.id ?? memberId).

  function flipCard(groupId: string, removed: boolean): void {
    const now = new Date()
    groups.value = groups.value.map((g) =>
      g.id === groupId
        ? {
            ...g,
            removed,
            number: relativeDuration(now),
            dateLabel: `${removed ? 'Removed' : 'Joined'} ${mediumDateShortTime(now)}`,
          }
        : g,
    )
  }

  async function removeFromGroup(groupId: string): Promise<void> {
    await axios.delete(`/admin/api/groups/${groupId}/members/${memberRecordId.value}`)
    flipCard(groupId, true)
  }

  async function rejoinGroup(groupId: string): Promise<void> {
    await axios.post(`/admin/api/groups/${groupId}/members`, {
      memberId: memberRecordId.value,
      role: 'member',
    })
    flipCard(groupId, false)
  }

  /** iOS transferMember: ADD to the target FIRST (while still active in the
   *  source the server recognizes the member as an org member and heals a
   *  missing org link), THEN remove from the source. No rollback — a failed
   *  step 2 leaves the member in both groups, exactly like iOS. */
  async function transferTo(
    fromGroupId: string,
    toGroupId: string,
    toGroupName: string,
    toCoverUrl?: string,
  ): Promise<void> {
    await axios.post(`/admin/api/groups/${toGroupId}/members`, {
      memberId: memberRecordId.value,
      role: 'member',
    })
    await axios.delete(`/admin/api/groups/${fromGroupId}/members/${memberRecordId.value}`)
    flipCard(fromGroupId, true)
    const existing = groups.value.find((g) => g.id === toGroupId)
    if (existing) {
      flipCard(toGroupId, false)
    } else {
      const now = new Date()
      // iOS synthesizes the card with name fallback "Group".
      groups.value = [
        ...groups.value,
        {
          id: toGroupId,
          name: toGroupName || 'Group',
          imageUrl: toCoverUrl || undefined,
          number: relativeDuration(now),
          dateLabel: `Joined ${mediumDateShortTime(now)}`,
          removed: false,
        },
      ]
    }
  }

  return {
    loading,
    error,
    loaded,
    displayName,
    avatarUrl,
    joined,
    age,
    phone,
    rawPhone,
    email,
    groups,
    memberRecordId,
    reset,
    loadMemberProfile,
    removeFromGroup,
    rejoinGroup,
    transferTo,
  }
})
