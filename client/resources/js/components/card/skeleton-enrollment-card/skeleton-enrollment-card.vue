<script setup lang="ts">
// SkeletonEnrollmentCard — skeleton/loading enrollment card (iOS
// Components/Domain/SkeletonEnrollmentCard.swift). Shown while an enrollment is
// being created. Data-driven via props.
//
// Layout (iOS): HStack(spacing 12), padding 12, white@5% background, 4px corner
// radius, 1px brandPrimary@30% border overlay. Left: 64×64 program cover (8px
// radius) — a book.fill placeholder on a brand-tint + black@20% wash (the
// AsyncImage never resolves in the isolated snapshot, so the placeholder always
// shows). Right column (spacing 4): program name (15pt semibold, white@70%, one
// line), "<days> days" (13pt, white@40%), and a status row (4px gap) of a small
// brand spoke spinner + "Creating…" (12pt medium, brand@70%).
//
// Props:
//   programName      string   — study/program title (1 line)
//   programDays      number   — day count rendered as "<n> days"
//   programImageUrl  string?   — cover URL; omitted in the isolated snapshot so
//                                the book placeholder always renders (matches iOS)
//   bookIcon         string?   — inline SVG for the book.fill placeholder glyph
import { computed } from 'vue'

interface Props {
  programName: string
  programDays: number
  programImageUrl?: string | null
  bookIcon?: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  programImageUrl: null,
  bookIcon: '',
})

const daysLabel = computed(() => `${props.programDays} days`)
</script>

<template>
  <div :class="['SkeletonEnrollmentCard', props.class]">
    <!-- Program cover / book placeholder (AsyncImage never resolves in snapshot) -->
    <div class="SkeletonEnrollmentCard__cover">
      <img
        v-if="programImageUrl"
        :src="programImageUrl"
        :alt="programName"
        class="SkeletonEnrollmentCard__image"
      />
      <div v-else class="SkeletonEnrollmentCard__placeholder" aria-hidden="true">
        <span
          v-if="bookIcon"
          class="SkeletonEnrollmentCard__book"
          v-html="bookIcon"
        />
      </div>
    </div>

    <!-- Program info + status -->
    <div class="SkeletonEnrollmentCard__body">
      <div class="SkeletonEnrollmentCard__name">{{ programName }}</div>
      <div class="SkeletonEnrollmentCard__days">{{ daysLabel }}</div>

      <div class="SkeletonEnrollmentCard__status">
        <span class="SkeletonEnrollmentCard__spinner" aria-hidden="true">
          <svg viewBox="0 0 24 24" stroke="currentColor" stroke-width="2" stroke-linecap="round">
            <line x1="12" y1="3.5" x2="12" y2="7.5" opacity="1" transform="rotate(0 12 12)" />
            <line x1="12" y1="3.5" x2="12" y2="7.5" opacity="0.9" transform="rotate(30 12 12)" />
            <line x1="12" y1="3.5" x2="12" y2="7.5" opacity="0.82" transform="rotate(60 12 12)" />
            <line x1="12" y1="3.5" x2="12" y2="7.5" opacity="0.73" transform="rotate(90 12 12)" />
            <line x1="12" y1="3.5" x2="12" y2="7.5" opacity="0.65" transform="rotate(120 12 12)" />
            <line x1="12" y1="3.5" x2="12" y2="7.5" opacity="0.56" transform="rotate(150 12 12)" />
            <line x1="12" y1="3.5" x2="12" y2="7.5" opacity="0.48" transform="rotate(180 12 12)" />
            <line x1="12" y1="3.5" x2="12" y2="7.5" opacity="0.4" transform="rotate(210 12 12)" />
            <line x1="12" y1="3.5" x2="12" y2="7.5" opacity="0.33" transform="rotate(240 12 12)" />
            <line x1="12" y1="3.5" x2="12" y2="7.5" opacity="0.27" transform="rotate(270 12 12)" />
            <line x1="12" y1="3.5" x2="12" y2="7.5" opacity="0.21" transform="rotate(300 12 12)" />
            <line x1="12" y1="3.5" x2="12" y2="7.5" opacity="0.16" transform="rotate(330 12 12)" />
          </svg>
        </span>
        <span class="SkeletonEnrollmentCard__statusLabel">Creating...</span>
      </div>
    </div>
  </div>
</template>
