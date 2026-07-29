<script lang="ts">
// MemberRequestsPage — twin of iPhone Pages/Manage/Member/MemberRequestsPage.swift.
// Presented through the `.page` chrome (managed-page.vue horizontal push — the
// only iOS route with that chrome). PageTitle "Member Requests" + either the
// empty state (person.badge.clock + "No pending requests") or a 4px-gap list
// of CardMember rows with a purple "Respond" pill and [Group]/[Requested]
// metadata chips (the Group chip is omitted when the group name is unknown —
// iOS omits it silently).
//
// Data-driven: strings arrive pre-formatted. Row add/remove animates
// scale+opacity over 300ms ease-in-out (iOS .transition(.scale + .opacity)
// under Motion.standard) via TransitionGroup — inert in static captures.
export interface MemberRequestRow {
  /** iOS GroupJoinRequest.id = "{groupId}-{requestId}". */
  id: string
  firstName: string
  lastName: string
  avatarUrl?: string
  /** Group name chip value; omit → chip omitted (iOS :143). */
  groupName?: string
  /** Pre-formatted "MMM d, yyyy" request date. */
  requestedLabel: string
}
</script>

<script setup lang="ts">
import CardMember, {
  type CardMemberMetaItem,
} from '../card-member/card-member.vue'
import PageTitle from '../page-title/page-title.vue'

interface Props {
  requests?: MemberRequestRow[]
  /** Capture-only simulator status bar. Production never passes it. */
  statusBar?: boolean
}

withDefaults(defineProps<Props>(), {
  requests: () => [],
  statusBar: false,
})

const emit = defineEmits<{
  back: []
  requestTap: [string]
  respond: [string]
}>()

const BACK_CHEVRON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 4l-7 8 7 8"/></svg>'
// SF "person.badge.clock" — empty-state glyph (Typography.s48 white@0.3).
const PERSON_CLOCK =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><circle cx="10" cy="7" r="3.5"/><path d="M3 20c.8-3.4 3.8-5.4 7-5.4 1 0 2 .2 2.9.6"/><circle cx="17.5" cy="17.5" r="4.3"/><path d="M17.5 15.4v2.3l1.6 1"/></svg>'

function meta(r: MemberRequestRow): CardMemberMetaItem[] {
  const items: CardMemberMetaItem[] = []
  if (r.groupName) items.push({ label: 'Group', value: r.groupName })
  items.push({ label: 'Requested', value: r.requestedLabel })
  return items
}
</script>

<template>
  <div class="MemberRequestsPage">
    <div v-if="statusBar" class="MemberRequestsPage__statusbar" aria-hidden="true">
      <span class="MemberRequestsPage__clock">9:41</span>
    </div>

    <PageTitle
      class="MemberRequestsPage__title"
      title="Member Requests"
      :left-icon="BACK_CHEVRON"
      @left="emit('back')"
    />

    <!-- Empty state — centered in the space below the header -->
    <div v-if="!requests.length" class="MemberRequestsPage__empty">
      <span class="MemberRequestsPage__emptyGlyph" aria-hidden="true" v-html="PERSON_CLOCK" />
      <p class="MemberRequestsPage__emptyTitle">No pending requests</p>
    </div>

    <!-- Request list -->
    <div v-else class="MemberRequestsPage__scroll">
      <TransitionGroup name="MemberRequestsPage-row" tag="div" class="MemberRequestsPage__cards">
        <CardMember
          v-for="r in requests"
          :key="r.id"
          :first-name="r.firstName"
          :last-name="r.lastName"
          :avatar-url="r.avatarUrl || undefined"
          :metadata="meta(r)"
          show-invite
          invite-label="Respond"
          @click="emit('requestTap', r.id)"
          @invite="emit('respond', r.id)"
        />
      </TransitionGroup>
    </div>
  </div>
</template>
