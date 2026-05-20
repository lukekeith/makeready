<script setup lang="ts">
import { ref, watch } from 'vue'
import Dialog from 'primevue/dialog'
import InputText from 'primevue/inputtext'
import Textarea from 'primevue/textarea'
import Select from 'primevue/select'
import ToggleSwitch from 'primevue/toggleswitch'
import InputNumber from 'primevue/inputnumber'
import Button from 'primevue/button'
import Message from 'primevue/message'

interface FieldOption { value: any; label: string }

interface FormField {
  key: string
  label: string
  type: 'text' | 'textarea' | 'toggle' | 'number' | 'select'
  required?: boolean
  placeholder?: string
  options?: FieldOption[]
}

interface Props {
  open: boolean
  title: string
  fields: FormField[]
  values: Record<string, any>
  error?: string
  saving?: boolean
  inline?: boolean
  hideCancelButton?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  saving: false,
  error: undefined,
  inline: false,
  hideCancelButton: false,
})

const emit = defineEmits<{
  (e: 'save', payload: Record<string, any>): void
  (e: 'cancel'): void
}>()

const formValues = ref<Record<string, any>>({})

watch(() => props.values, (v) => { formValues.value = { ...v } }, { immediate: true, deep: true })
watch(() => props.open, (isOpen) => { if (isOpen) formValues.value = { ...props.values } })

function handleSave(): void { emit('save', { ...formValues.value }) }
function handleCancel(): void { emit('cancel') }
</script>

<template>
  <!-- Inline mode -->
  <div v-if="inline" style="display: flex; flex-direction: column; gap: 1rem;">
    <h2 style="font-size: 1.125rem; font-weight: 600; margin: 0;">{{ title }}</h2>
    <Message v-if="error" severity="error" :closable="false">{{ error }}</Message>

    <div v-for="field in fields" :key="field.key" style="display: flex; flex-direction: column; gap: 0.375rem;">
      <label :for="field.key" style="font-size: 0.875rem; font-weight: 500;">
        {{ field.label }}<span v-if="field.required" style="color: var(--p-red-500);"> *</span>
      </label>
      <InputText v-if="field.type === 'text'" :id="field.key" v-model="formValues[field.key]" :placeholder="field.placeholder" fluid />
      <Textarea v-else-if="field.type === 'textarea'" :id="field.key" v-model="formValues[field.key]" :placeholder="field.placeholder" :rows="3" fluid />
      <ToggleSwitch v-else-if="field.type === 'toggle'" :id="field.key" v-model="formValues[field.key]" />
      <InputNumber v-else-if="field.type === 'number'" :id="field.key" v-model="formValues[field.key]" :placeholder="field.placeholder" fluid />
      <Select v-else-if="field.type === 'select'" :id="field.key" v-model="formValues[field.key]" :options="field.options" option-label="label" option-value="value" :placeholder="field.placeholder || 'Select an option'" fluid />
    </div>

    <div style="display: flex; gap: 0.5rem; justify-content: flex-end;">
      <Button v-if="!hideCancelButton" label="Cancel" severity="secondary" outlined @click="handleCancel" />
      <Button :label="saving ? 'Saving...' : 'Save'" :disabled="saving" @click="handleSave" />
    </div>
  </div>

  <!-- Modal mode -->
  <Dialog v-else :visible="open" :header="title" modal :style="{ width: '32rem' }" @update:visible="(v) => !v && handleCancel()">
    <Message v-if="error" severity="error" :closable="false" style="margin-bottom: 1rem;">{{ error }}</Message>

    <div style="display: flex; flex-direction: column; gap: 1rem;">
      <div v-for="field in fields" :key="field.key" style="display: flex; flex-direction: column; gap: 0.375rem;">
        <label :for="field.key" style="font-size: 0.875rem; font-weight: 500;">
          {{ field.label }}<span v-if="field.required" style="color: var(--p-red-500);"> *</span>
        </label>
        <InputText v-if="field.type === 'text'" :id="field.key" v-model="formValues[field.key]" :placeholder="field.placeholder" fluid />
        <Textarea v-else-if="field.type === 'textarea'" :id="field.key" v-model="formValues[field.key]" :placeholder="field.placeholder" :rows="3" fluid />
        <ToggleSwitch v-else-if="field.type === 'toggle'" :id="field.key" v-model="formValues[field.key]" />
        <InputNumber v-else-if="field.type === 'number'" :id="field.key" v-model="formValues[field.key]" :placeholder="field.placeholder" fluid />
        <Select v-else-if="field.type === 'select'" :id="field.key" v-model="formValues[field.key]" :options="field.options" option-label="label" option-value="value" :placeholder="field.placeholder || 'Select an option'" fluid />
      </div>
    </div>

    <template #footer>
      <Button v-if="!hideCancelButton" label="Cancel" severity="secondary" outlined @click="handleCancel" />
      <Button :label="saving ? 'Saving...' : 'Save'" :disabled="saving" @click="handleSave" />
    </template>
  </Dialog>
</template>
