<script setup lang="ts">
import { onMounted, ref, computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useGroupsDomain } from '../stores/domain/groups.domain'
import { useGroupsListUI } from '../stores/ui/groups-list.ui'
import { useGroupDetailUI } from '../stores/ui/group-detail.ui'
import { useMembersTabUI } from '../stores/ui/members-tab.ui'
import { useMembersDomain } from '../stores/domain/members.domain'
import { useEnrollmentsTabUI } from '../stores/ui/enrollments-tab.ui'
import { usePostsTabUI } from '../stores/ui/posts-tab.ui'
import type { PostType } from '../stores/domain/posts.domain'
import AdminTable from '../../../components/admin/admin-table/admin-table.vue'
import AdminForm from '../../../components/admin/admin-form/admin-form.vue'
import AdminConfirmDialog from '../../../components/admin/admin-confirm-dialog/admin-confirm-dialog.vue'
import AdminImageUpload from '../../../components/admin/admin-image-upload/admin-image-upload.vue'
import Button from 'primevue/button'
import Tabs from 'primevue/tabs'
import TabList from 'primevue/tablist'
import Tab from 'primevue/tab'
import TabPanels from 'primevue/tabpanels'
import TabPanel from 'primevue/tabpanel'
import Dialog from 'primevue/dialog'
import Select from 'primevue/select'
import InputText from 'primevue/inputtext'
import Textarea from 'primevue/textarea'
import Skeleton from 'primevue/skeleton'
import Avatar from 'primevue/avatar'
import Card from 'primevue/card'
import Tag from 'primevue/tag'
import Message from 'primevue/message'
import Divider from 'primevue/divider'

const domain = useGroupsDomain()
const listUI = useGroupsListUI()
const detailUI = useGroupDetailUI()
const membersUI = useMembersTabUI()
const membersDomain = useMembersDomain()
const enrollmentsUI = useEnrollmentsTabUI()
const postsUI = usePostsTabUI()
const route = useRoute()
const router = useRouter()
const isSaving = ref(false)
const ALL_DAYS = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'] as const

function parseDays(enabledDays: string): string { try { return JSON.parse(enabledDays).join(', ') } catch { return enabledDays } }

const unenrollMessage = computed(() => {
  const info = enrollmentsUI.unenrollInfo
  if (!info) return 'Are you sure you want to delete this enrollment?'
  return `This enrollment has ${info.totalLessons} lessons (${info.lessonsWithData} with member data). Deleting will remove all scheduled lessons.`
})

onMounted(async () => {
  if (route.params.id) { await domain.getGroup(route.params.id as string); membersUI.loadData(); enrollmentsUI.loadData(); postsUI.loadData() }
  else { await domain.loadGroups() }
})

watch(() => route.params.id, async (newId) => {
  if (newId) { await domain.getGroup(newId as string); membersUI.loadData(); enrollmentsUI.loadData(); postsUI.loadData() }
})

const createFields = [
  { key: 'name', label: 'Group Name', type: 'text' as const, required: true, placeholder: 'Enter group name' },
  { key: 'description', label: 'Description', type: 'textarea' as const, placeholder: 'Describe this group (optional)' },
]
const editFields = [...createFields]

const roleOptions = [{ label: 'Admin', value: 'ADMIN' }, { label: 'Member', value: 'MEMBER' }]
const timezoneOptions = [
  { label: 'Default', value: '' }, { label: 'Eastern', value: 'America/New_York' }, { label: 'Central', value: 'America/Chicago' },
  { label: 'Mountain', value: 'America/Denver' }, { label: 'Pacific', value: 'America/Los_Angeles' }, { label: 'Arizona', value: 'America/Phoenix' },
  { label: 'Alaska', value: 'America/Anchorage' }, { label: 'Hawaii', value: 'Pacific/Honolulu' },
]

async function handleCreate(p: Record<string, any>) { isSaving.value = true; listUI.formError = null; try { await domain.createGroup(p); listUI.closeForm() } catch (e: any) { listUI.formError = e?.response?.data?.message ?? 'Failed to create group' } finally { isSaving.value = false } }
async function handleUpdate(p: Record<string, any>) { if (!listUI.editingGroup) return; isSaving.value = true; listUI.formError = null; try { await domain.updateGroup(listUI.editingGroup.id, p); listUI.closeForm() } catch (e: any) { listUI.formError = e?.response?.data?.message ?? 'Failed to update group' } finally { isSaving.value = false } }
async function handleDelete() { if (!listUI.confirmDeleteGroup) return; try { await domain.deleteGroup(listUI.confirmDeleteGroup.id) } finally { listUI.cancelDelete() } }
async function handleSettingsSave(p: Record<string, any>) { detailUI.isSavingSettings = true; detailUI.settingsError = null; try { await domain.updateGroup(route.params.id as string, p) } catch (e: any) { detailUI.settingsError = e?.response?.data?.message ?? 'Failed to save' } finally { detailUI.isSavingSettings = false } }
async function handleCoverUpload(file: File) { detailUI.isUploadingCover = true; try { await domain.uploadCoverImage(route.params.id as string, file) } finally { detailUI.isUploadingCover = false } }
async function handleApprove(id: string) { try { await membersDomain.approveRequest(route.params.id as string, id) } catch (e: any) { alert(e?.message ?? 'Failed') } }
async function handleReject(id: string) { try { await membersDomain.rejectRequest(route.params.id as string, id) } catch (e: any) { alert(e?.message ?? 'Failed') } }
async function handleRoleChange(memberId: string, newRole: string) { try { await membersDomain.changeRole(route.params.id as string, memberId, newRole as 'ADMIN' | 'MEMBER') } catch (e: any) { alert(e?.message ?? 'Failed') } }
</script>

<template>
  <!-- Detail View -->
  <template v-if="route.params.id">
    <div style="display: flex; flex-direction: column; gap: 1.5rem;">
      <div>
        <Button label="Back to Groups" icon="pi pi-arrow-left" severity="secondary" text @click="router.push('/admin/groups')" />
        <h1 style="font-size: 1.5rem; font-weight: 700; margin: 0.5rem 0 0;">{{ detailUI.pageTitle }}</h1>
      </div>

      <AdminImageUpload :current-url="detailUI.currentGroup?.coverImageUrl" :uploading="detailUI.isUploadingCover" label="Group Cover Image" @upload="handleCoverUpload" />

      <Tabs :value="detailUI.activeTab" @update:value="(v) => detailUI.activeTab = v">
        <TabList>
          <Tab value="members">Members</Tab>
          <Tab value="enrollments">Enrollments</Tab>
          <Tab value="posts">Posts</Tab>
          <Tab value="settings">Settings</Tab>
        </TabList>
        <TabPanels>
          <TabPanel value="members">
            <div style="display: flex; flex-direction: column; gap: 1rem; padding-top: 1rem;">
              <template v-if="membersUI.hasPending">
                <h4 style="margin: 0;">Pending Requests ({{ membersUI.pendingRequests.length }})</h4>
                <Card v-for="req in membersUI.pendingRequests" :key="req.id">
                  <template #content>
                    <div style="display: flex; align-items: center; justify-content: space-between;">
                      <div style="display: flex; align-items: center; gap: 0.75rem;">
                        <Avatar v-if="req.member.avatarUrl" :image="req.member.avatarUrl" shape="circle" />
                        <Avatar v-else :label="(req.member.firstName?.[0] ?? '') + (req.member.lastName?.[0] ?? '')" shape="circle" />
                        <div><div style="font-weight: 500;">{{ req.member.firstName }} {{ req.member.lastName }}</div><small style="color: var(--p-text-muted-color);">{{ new Date(req.createdAt).toLocaleDateString() }}</small></div>
                      </div>
                      <div style="display: flex; gap: 0.5rem;"><Button label="Approve" size="small" @click="handleApprove(req.id)" /><Button label="Reject" severity="danger" size="small" @click="handleReject(req.id)" /></div>
                    </div>
                  </template>
                </Card>
              </template>

              <h4 style="margin: 0;">Members ({{ membersUI.members.length }})</h4>
              <div v-if="membersUI.isLoading" style="display: flex; flex-direction: column; gap: 0.5rem;"><Skeleton v-for="i in 3" :key="i" height="3.5rem" /></div>
              <div v-else-if="membersUI.members.length === 0" style="color: var(--p-text-muted-color);">No members in this group.</div>
              <Card v-for="member in membersUI.members" :key="member.id" v-else style="cursor: pointer;" @click="membersUI.openProfile(member.id)">
                <template #content>
                  <div style="display: flex; align-items: center; justify-content: space-between;">
                    <div style="display: flex; align-items: center; gap: 0.75rem;">
                      <Avatar v-if="member.avatarUrl" :image="member.avatarUrl" shape="circle" />
                      <Avatar v-else :label="member.name?.[0] ?? '?'" shape="circle" />
                      <div><div style="font-weight: 500;">{{ member.name }}</div><small style="color: var(--p-text-muted-color);">{{ new Date(member.joinedAt).toLocaleDateString() }}</small></div>
                    </div>
                    <div style="display: flex; align-items: center; gap: 0.5rem;" @click.stop>
                      <Select v-if="member.role !== 'OWNER'" :model-value="member.role" :options="roleOptions" option-label="label" option-value="value" :style="{ width: '7rem' }" @change="(e) => handleRoleChange(member.id, e.value)" />
                      <small v-else style="color: var(--p-text-muted-color); text-transform: capitalize;">{{ member.role.toLowerCase() }}</small>
                      <Button v-if="member.role !== 'OWNER'" icon="pi pi-user-minus" severity="danger" text rounded size="small" @click="membersUI.requestRemove(member.id)" />
                    </div>
                  </div>
                </template>
              </Card>

              <Dialog :visible="membersUI.isProfileOpen" header="Member Profile" modal :style="{ width: '24rem' }" @update:visible="(v) => !v && membersUI.closeProfile()">
                <template v-if="membersUI.profileData">
                  <div style="display: flex; align-items: center; gap: 0.75rem; margin-bottom: 1rem;">
                    <Avatar v-if="membersUI.profileData.profilePicture" :image="membersUI.profileData.profilePicture" size="large" shape="circle" />
                    <Avatar v-else :label="(membersUI.profileData.firstName?.[0] ?? '') + (membersUI.profileData.lastName?.[0] ?? '')" size="large" shape="circle" />
                    <span style="font-weight: 600;">{{ membersUI.profileData.firstName }} {{ membersUI.profileData.lastName }}</span>
                  </div>
                  <div style="display: flex; flex-direction: column; gap: 0.75rem; font-size: 0.875rem;">
                    <div><small style="color: var(--p-text-muted-color);">Email</small><div>{{ membersUI.profileData.email ?? 'Not provided' }}</div></div>
                    <div><small style="color: var(--p-text-muted-color);">Phone</small><div>{{ membersUI.profileData.phoneNumber ?? 'Not provided' }}</div></div>
                    <div v-if="membersUI.profileData.groups?.length"><small style="color: var(--p-text-muted-color);">Groups</small><div v-for="g in membersUI.profileData.groups" :key="g.id" style="color: var(--p-text-muted-color);">{{ g.name }} ({{ g.role.toLowerCase() }})</div></div>
                  </div>
                </template>
                <template #footer><Button label="Close" @click="membersUI.closeProfile()" /></template>
              </Dialog>

              <AdminConfirmDialog :open="!!membersUI.confirmRemoveId" title="Remove Member" message="Are you sure you want to remove this member from the group? They will need to rejoin." confirm-label="Remove" :dangerous="true" @confirm="membersUI.confirmRemove()" @cancel="membersUI.cancelRemove()" />
            </div>
          </TabPanel>

          <TabPanel value="enrollments">
            <div style="display: flex; flex-direction: column; gap: 1rem; padding-top: 1rem;">
              <div style="display: flex; justify-content: flex-end;"><Button label="New Enrollment" icon="pi pi-plus" size="small" @click="enrollmentsUI.openCreate()" /></div>

              <Card v-if="enrollmentsUI.isCreateFormOpen">
                <template #title>New Enrollment</template>
                <template #content>
                  <div style="display: flex; flex-direction: column; gap: 1rem;">
                    <div style="display: flex; flex-direction: column; gap: 0.25rem;"><label style="font-weight: 500;">Program *</label><Select v-model="enrollmentsUI.createForm.studyProgramId" :options="enrollmentsUI.programOptions" option-label="label" option-value="value" placeholder="Select a program" fluid /></div>
                    <div style="display: flex; flex-direction: column; gap: 0.25rem;"><label style="font-weight: 500;">Start Date *</label><InputText v-model="enrollmentsUI.createForm.startDate" type="date" fluid /></div>
                    <div style="display: flex; flex-direction: column; gap: 0.25rem;"><label style="font-weight: 500;">Enabled Days</label><div style="display: flex; flex-wrap: wrap; gap: 0.75rem;"><div v-for="day in ALL_DAYS" :key="day" style="display: flex; align-items: center; gap: 0.375rem;"><input :id="'day-' + day" type="checkbox" :value="day" v-model="enrollmentsUI.selectedDays" /><label :for="'day-' + day">{{ day.charAt(0) + day.slice(1).toLowerCase() }}</label></div></div></div>
                    <div style="display: flex; flex-direction: column; gap: 0.25rem;"><label style="font-weight: 500;">SMS Time</label><InputText v-model="enrollmentsUI.createForm.smsTime" type="time" placeholder="08:00" fluid /></div>
                    <div style="display: flex; flex-direction: column; gap: 0.25rem;"><label style="font-weight: 500;">Timezone</label><Select v-model="enrollmentsUI.createForm.timezone" :options="timezoneOptions" option-label="label" option-value="value" fluid /></div>
                    <Message v-if="enrollmentsUI.formError" severity="error" :closable="false">{{ enrollmentsUI.formError }}</Message>
                    <div style="display: flex; justify-content: flex-end; gap: 0.5rem;"><Button label="Cancel" severity="secondary" outlined @click="enrollmentsUI.closeCreate()" /><Button :label="enrollmentsUI.isSaving ? 'Saving...' : 'Create Enrollment'" :disabled="enrollmentsUI.isSaving" @click="enrollmentsUI.submitCreate()" /></div>
                  </div>
                </template>
              </Card>

              <div v-if="enrollmentsUI.isLoading" style="color: var(--p-text-muted-color);">Loading enrollments...</div>
              <div v-else-if="enrollmentsUI.enrollments.length === 0" style="color: var(--p-text-muted-color);">No enrollments for this group.</div>
              <template v-else v-for="enrollment in enrollmentsUI.enrollments" :key="enrollment.id">
                <Card style="cursor: pointer;" @click="enrollmentsUI.expandedEnrollmentId === enrollment.id ? enrollmentsUI.collapseEnrollment() : enrollmentsUI.expandEnrollment(enrollment.id)">
                  <template #content>
                    <div style="display: flex; align-items: center; justify-content: space-between;">
                      <div><div style="font-weight: 500;">{{ enrollment.studyProgram?.name ?? 'Unknown Program' }}</div><small style="color: var(--p-text-muted-color);">{{ new Date(enrollment.startDate).toLocaleDateString() }} — {{ new Date(enrollment.endDate).toLocaleDateString() }}</small><br/><small style="color: var(--p-text-muted-color);">Days: {{ parseDays(enrollment.enabledDays) }}</small></div>
                      <div style="display: flex; align-items: center; gap: 0.25rem;" @click.stop>
                        <Button icon="pi pi-ban" severity="secondary" text rounded size="small" @click="enrollmentsUI.handleCancelFuture(enrollment.id)" title="Cancel future lessons" />
                        <Button icon="pi pi-trash" severity="danger" text rounded size="small" @click="enrollmentsUI.requestDelete(enrollment.id)" />
                        <i :class="enrollmentsUI.expandedEnrollmentId === enrollment.id ? 'pi pi-chevron-up' : 'pi pi-chevron-down'" style="color: var(--p-text-muted-color);" />
                      </div>
                    </div>
                  </template>
                </Card>
                <Card v-if="enrollmentsUI.expandedEnrollmentId === enrollment.id && enrollmentsUI.enrollmentDetail">
                  <template #content>
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.75rem;">
                      <span style="font-weight: 500;">Lesson Schedule ({{ enrollmentsUI.enrollmentDetail.lessonSchedules.length }})</span>
                      <Button label="Add Lesson" icon="pi pi-plus" severity="secondary" outlined size="small" @click.stop="enrollmentsUI.addSchedule()" />
                    </div>
                    <div v-for="schedule in enrollmentsUI.enrollmentDetail.lessonSchedules" :key="schedule.id" style="display: flex; align-items: center; gap: 0.75rem; padding: 0.5rem 0; border-bottom: 1px solid var(--p-content-border-color);">
                      <small style="color: var(--p-text-muted-color); width: 5rem; flex-shrink: 0;">{{ new Date(schedule.scheduledDate).toLocaleDateString() }}</small>
                      <div v-if="enrollmentsUI.editingScheduleId === schedule.id" style="display: flex; flex: 1; align-items: center; gap: 0.5rem;" @click.stop>
                        <InputText v-model="enrollmentsUI.editingTitle" fluid @keyup.enter="enrollmentsUI.saveScheduleTitle()" @keyup.escape="enrollmentsUI.cancelEditSchedule()" />
                        <Button label="Save" size="small" @click="enrollmentsUI.saveScheduleTitle()" />
                        <Button label="Cancel" severity="secondary" outlined size="small" @click="enrollmentsUI.cancelEditSchedule()" />
                      </div>
                      <div v-else style="flex: 1; font-size: 0.875rem; cursor: pointer; display: flex; align-items: center;" @click.stop="enrollmentsUI.startEditSchedule(schedule.id, schedule.title ?? schedule.lesson?.title ?? '')">
                        {{ schedule.title ?? schedule.lesson?.title ?? 'Untitled' }} <i class="pi pi-pencil" style="font-size: 0.75rem; opacity: 0.4; margin-left: 0.25rem;" />
                      </div>
                      <small v-if="schedule.lesson" style="color: var(--p-text-muted-color);">Day {{ schedule.lesson.dayNumber }}</small>
                      <Button icon="pi pi-trash" severity="secondary" text rounded size="small" @click.stop="enrollmentsUI.requestDeleteSchedule(schedule.id)" />
                    </div>
                  </template>
                </Card>
              </template>

              <AdminConfirmDialog :open="!!enrollmentsUI.confirmDeleteId" title="Delete Enrollment" :message="unenrollMessage" confirm-label="Delete Enrollment" :dangerous="true" @confirm="enrollmentsUI.confirmDelete()" @cancel="enrollmentsUI.cancelDelete()" />
              <AdminConfirmDialog :open="!!enrollmentsUI.confirmDeleteScheduleId" title="Delete Scheduled Lesson" message="Are you sure you want to delete this scheduled lesson?" confirm-label="Delete" :dangerous="true" @confirm="enrollmentsUI.confirmDeleteSchedule()" @cancel="enrollmentsUI.cancelDeleteSchedule()" />
            </div>
          </TabPanel>

          <TabPanel value="posts">
            <div style="display: flex; flex-direction: column; gap: 1rem; padding-top: 1rem;">
              <div style="display: flex; justify-content: flex-end;"><Button label="New Post" icon="pi pi-plus" size="small" @click="postsUI.openCreate()" /></div>

              <Card v-if="postsUI.isCreateFormOpen">
                <template #content>
                  <div style="display: flex; flex-direction: column; gap: 1rem;">
                    <div style="display: flex; gap: 0.5rem; flex-wrap: wrap;">
                      <Button v-for="ptype in (['ANNOUNCEMENT','POLL','EVENT','VIDEO'] as PostType[])" :key="ptype" :label="ptype.charAt(0) + ptype.slice(1).toLowerCase()" :severity="postsUI.selectedType === ptype ? 'primary' : 'secondary'" :outlined="postsUI.selectedType !== ptype" size="small" @click="postsUI.selectedType = ptype" />
                    </div>
                    <div v-if="postsUI.selectedType !== 'POLL'" style="display: flex; flex-direction: column; gap: 0.25rem;"><label style="font-weight: 500;">Title</label><InputText v-model="postsUI.formTitle" placeholder="Post title (optional)" fluid /></div>
                    <div style="display: flex; flex-direction: column; gap: 0.25rem;"><label style="font-weight: 500;">{{ postsUI.selectedType === 'POLL' ? 'Question' : 'Content' }} *</label><Textarea v-model="postsUI.formContent" :placeholder="postsUI.selectedType === 'POLL' ? 'Ask a question...' : 'Write your post...'" :rows="3" fluid /></div>
                    <template v-if="postsUI.selectedType === 'POLL'"><div style="display: flex; flex-direction: column; gap: 0.5rem;"><label style="font-weight: 500;">Options</label><div v-for="(opt, idx) in postsUI.pollOptions" :key="idx" style="display: flex; align-items: center; gap: 0.5rem;"><InputText v-model="postsUI.pollOptions[idx]" :placeholder="'Option ' + (idx + 1)" fluid /><Button v-if="postsUI.pollOptions.length > 2" icon="pi pi-times" severity="secondary" text rounded size="small" @click="postsUI.removePollOption(idx)" /></div><Button label="+ Add Option" severity="secondary" outlined size="small" @click="postsUI.addPollOption()" /></div></template>
                    <div v-if="postsUI.selectedType === 'VIDEO'" style="display: flex; flex-direction: column; gap: 0.25rem;"><label style="font-weight: 500;">Video URL *</label><InputText v-model="postsUI.formVideoUrl" placeholder="https://..." fluid /></div>
                    <template v-if="postsUI.selectedType === 'EVENT'"><div style="display: flex; flex-direction: column; gap: 0.25rem;"><label style="font-weight: 500;">Event Date *</label><InputText v-model="postsUI.formEventDate" type="datetime-local" fluid /></div><div style="display: flex; flex-direction: column; gap: 0.25rem;"><label style="font-weight: 500;">Location</label><InputText v-model="postsUI.formEventLocation" placeholder="Event location (optional)" fluid /></div></template>
                    <Message v-if="postsUI.formError" severity="error" :closable="false">{{ postsUI.formError }}</Message>
                    <div style="display: flex; justify-content: flex-end; gap: 0.5rem;"><Button label="Cancel" severity="secondary" outlined @click="postsUI.closeCreate()" /><Button :label="postsUI.isSaving ? 'Saving...' : 'Create Post'" :disabled="postsUI.isSaving" @click="postsUI.submitCreate()" /></div>
                  </div>
                </template>
              </Card>

              <div v-if="postsUI.isLoading && postsUI.posts.length === 0" style="color: var(--p-text-muted-color);">Loading posts...</div>
              <div v-else-if="postsUI.posts.length === 0" style="color: var(--p-text-muted-color);">No posts in this group.</div>
              <Card v-for="post in postsUI.posts" :key="post.id" v-else>
                <template #content>
                  <div style="display: flex; align-items: center; gap: 0.5rem; margin-bottom: 0.5rem;">
                    <Avatar v-if="post.authorAvatarUrl" :image="post.authorAvatarUrl" shape="circle" />
                    <Avatar v-else :label="post.authorName?.[0] ?? '?'" shape="circle" />
                    <span style="font-weight: 500;">{{ post.authorName }}</span>
                    <Tag :value="post.type" severity="secondary" />
                    <small style="margin-left: auto; color: var(--p-text-muted-color);">{{ new Date(post.createdAt).toLocaleDateString() }}</small>
                  </div>
                  <div v-if="post.title" style="font-weight: 500; margin-bottom: 0.25rem;">{{ post.title }}</div>
                  <div style="color: var(--p-text-muted-color);">{{ post.content }}</div>
                  <div v-if="post.type === 'POLL' && post.pollOptions?.length" style="margin-top: 0.5rem;"><div v-for="opt in post.pollOptions" :key="opt.id" style="color: var(--p-text-muted-color); font-size: 0.875rem;">{{ opt.text }} ({{ opt.voteCount }} votes)</div></div>
                  <small v-if="post.type === 'EVENT'" style="color: var(--p-text-muted-color);"><span v-if="post.eventDate">{{ new Date(post.eventDate).toLocaleString() }}</span><span v-if="post.eventLocation"> · {{ post.eventLocation }}</span></small>
                  <div v-if="post.type === 'VIDEO' && post.videoUrl"><a :href="post.videoUrl" target="_blank" style="font-size: 0.75rem;">{{ post.videoUrl }}</a></div>
                </template>
              </Card>
              <div v-if="postsUI.hasMore" style="display: flex; justify-content: center;"><Button label="Load More" severity="secondary" outlined @click="postsUI.loadMore()" /></div>
            </div>
          </TabPanel>

          <TabPanel value="settings">
            <div style="padding-top: 1rem;">
              <AdminForm :key="'settings-' + (detailUI.currentGroup?.id ?? 'none')" :open="true" :inline="true" :hide-cancel-button="true" title="Group Settings" :fields="detailUI.settingsFields" :values="detailUI.settingsFormValues" :error="detailUI.settingsError ?? undefined" :saving="detailUI.isSavingSettings" @save="handleSettingsSave" @cancel="() => {}" />
            </div>
          </TabPanel>
        </TabPanels>
      </Tabs>
    </div>
  </template>

  <!-- List View -->
  <template v-else>
    <div style="display: flex; flex-direction: column; gap: 1.5rem;">
      <div style="display: flex; align-items: center; justify-content: space-between;">
        <h1 style="font-size: 1.5rem; font-weight: 700; margin: 0;">Groups</h1>
        <Button label="+ Create Group" @click="listUI.openCreateForm" />
      </div>
      <AdminTable :columns="listUI.tableColumns" :rows="listUI.tableRows" :loading="domain.isLoading" empty-message="No groups yet. Create your first group." @row-click="listUI.navigateToDetail" @edit="listUI.openEditForm" @delete="listUI.requestDelete" />
      <AdminForm :key="listUI.editingGroupId ?? 'create'" :open="listUI.isCreateFormOpen" :title="listUI.isEditing ? 'Edit Group' : 'Create Group'" :fields="listUI.isEditing ? editFields : createFields" :values="listUI.isEditing ? { name: listUI.editingGroup?.name ?? '', description: listUI.editingGroup?.description ?? '' } : {}" :error="listUI.formError ?? undefined" :saving="isSaving" @save="listUI.isEditing ? handleUpdate($event) : handleCreate($event)" @cancel="listUI.closeForm" />
      <AdminConfirmDialog :open="!!listUI.confirmDeleteGroup" title="Delete Group" :message="`Are you sure you want to delete &quot;${listUI.confirmDeleteGroup?.name ?? ''}&quot;? This cannot be undone.`" @confirm="handleDelete" @cancel="listUI.cancelDelete" />
    </div>
  </template>
</template>
