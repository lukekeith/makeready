<script setup lang="ts">
import { ref, computed, watch, nextTick, onMounted } from "vue";
import { marked } from "marked";
import {
    isStableNumberedScriptureMarkdown,
    normalizeScriptureMarkdown,
} from "@/utils/scripture-content-normalizer";
import { useLessonState } from "../use-lesson-state";

interface ExegesisHighlight {
    id: string;
    orderNumber: number;
    start: number;
    end: number;
    noteMarkdown: string;
}

interface ReadBlockSelection {
    start: number;
    end: number;
    style: string;
}

interface ReadBlock {
    id: string;
    title?: string;
    content?: string;
    sourceReferenceId?: string;
    isLocked?: boolean;
    contentFormat?: "html" | "markdown";
    backgroundImageUrl?: string | null;
    backgroundColor?: string | null;
    backgroundOverlayOpacity?: number | null;
    fontSize?: string | null;
    selections?: ReadBlockSelection[] | null;
    exegesisHighlights?: ExegesisHighlight[];
}

interface ActivityProgress {
    completedAt?: string | null;
    exegesisVisitedHighlightIds?: string[] | null;
}

interface Activity {
    id: string;
    type: string;
    title?: string;
    readBlocks?: ReadBlock[];
    progress?: ActivityProgress | null;
}

interface Props {
    activity: Activity;
    groupId: string;
    lessonScheduleId: string;
    fullScreen?: boolean;
    initialHighlightIndex?: number | null;
}

const props = withDefaults(defineProps<Props>(), {
    fullScreen: false,
    initialHighlightIndex: null,
});

const emit = defineEmits<{
    visit: [activityId: string, highlightId: string];
    complete: [value: boolean];
    "hide-title": [value: boolean];
}>();

const lessonState = useLessonState();

// Exegesis should show the lesson title in the header.
emit("hide-title", false);

const containerRef = ref<HTMLElement | null>(null);
const overlayRef = ref<HTMLElement | null>(null);
const overlayOpen = ref(false);
const overlayHeight = ref(0);

const ACTIVE_HIGHLIGHT_TOP_PADDING = 24;
const OVERLAY_BOTTOM_SAFE_PADDING = 32;

const lockedBlock = computed<ReadBlock | null>(() => {
    const blocks = props.activity.readBlocks ?? [];
    return blocks.find((b) => b.isLocked) ?? blocks[0] ?? null;
});

const highlights = computed<ExegesisHighlight[]>(() => {
    const block = lockedBlock.value;
    const hs = block?.exegesisHighlights ?? [];
    if (hs.length > 0) {
        return [...hs].sort(
            (a, b) =>
                a.start - b.start ||
                a.end - b.end ||
                a.orderNumber - b.orderNumber,
        );
    }

    // Older scheduled lesson payloads may only have read-block selections copied
    // from the creator-side exegesis highlights. Paint those ranges too so the
    // member experience doesn't depend on which backend representation arrived.
    const selections = block?.selections ?? [];
    return selections
        .filter((selection) => selection.style === "highlight")
        .map((selection, index) => ({
            id: `selection-${index}-${selection.start}-${selection.end}`,
            orderNumber: index + 1,
            start: selection.start,
            end: selection.end,
            noteMarkdown: "",
        }))
        .sort(
            (a, b) =>
                a.start - b.start ||
                a.end - b.end ||
                a.orderNumber - b.orderNumber,
        );
});

const visited = ref<Set<string>>(new Set());

const activeIndex = ref<number | null>(null);
const activeHighlight = computed(() =>
    activeIndex.value == null
        ? null
        : (highlights.value[activeIndex.value] ?? null),
);

const promptedHighlightId = computed(
    () =>
        highlights.value.find((highlight) => !visited.value.has(highlight.id))
            ?.id ?? null,
);

const activeNoteHtml = computed(() => {
    const h = activeHighlight.value;
    if (!h) return "";
    // marked is already used throughout the app for theme rendering; keep
    // exegesis notes consistent with other markdown surfaces.
    return marked.parse(h.noteMarkdown ?? "") as string;
});

const isComplete = computed(() => {
    const total = highlights.value.length;
    if (total === 0) return false;
    return visited.value.size >= total;
});

watch(isComplete, (val) => emit("complete", val), { immediate: true });

// Report progress to lesson state — updates as highlights are visited
watch(
    [visited, highlights],
    () => {
        const total = highlights.value.length;
        const done = visited.value.size;
        if (total === 0) return;
        if (done >= total) {
            lessonState.reportProgress("All highlights reviewed", true);
        } else {
            lessonState.reportProgress(`Tap each highlight (${done} of ${total})`, false);
        }
    },
    { immediate: true, deep: true },
);

watch([overlayOpen, activeHighlight], () => {
    nextTick(() => updateOverlayHeight());
});

function fontSizeStyle(key?: string | null): string {
    switch ((key ?? "m").toLowerCase()) {
        case "xs":
            return "1.0em";
        case "s":
            return "1.2em";
        case "m":
            return "1.4em";
        case "lg":
            return "1.7em";
        case "xl":
            return "2.0em";
        default:
            return "1.4em";
    }
}

function hexToRgbTuple(hex: string): string {
    const m3 = /^#?([0-9a-f])([0-9a-f])([0-9a-f])$/i.exec(hex);
    if (m3) {
        const [, r, g, b] = m3;
        return `${parseInt(r + r, 16)}, ${parseInt(g + g, 16)}, ${parseInt(b + b, 16)}`;
    }
    const m6 = /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(hex);
    if (m6) {
        const [, r, g, b] = m6;
        return `${parseInt(r, 16)}, ${parseInt(g, 16)}, ${parseInt(b, 16)}`;
    }
    return "0, 0, 0";
}

const containerStyle = computed<Record<string, string>>(() => {
    const block = lockedBlock.value;
    const img = block?.backgroundImageUrl ?? null;
    const col = block?.backgroundColor ?? null;
    const opacity = block?.backgroundOverlayOpacity ?? 0.8;
    const fontSize = fontSizeStyle(block?.fontSize);

    const base: Record<string, string> = { fontSize };

    if (img && col) {
        const rgb = hexToRgbTuple(col);
        base.background = `linear-gradient(rgba(${rgb}, ${opacity}), rgba(${rgb}, ${opacity})), url(${JSON.stringify(img).slice(1, -1)}) center/cover no-repeat`;
        return base;
    }
    if (col) {
        base.backgroundColor = col;
        return base;
    }
    if (img) {
        base.backgroundImage = `url(${JSON.stringify(img).slice(1, -1)})`;
        base.backgroundSize = "cover";
        base.backgroundPosition = "center";
        base.backgroundRepeat = "no-repeat";
        return base;
    }
    return base;
});

const verseContainerStyle = computed<Record<string, string>>(() => {
    const bottomPadding =
        overlayOpen.value && activeHighlight.value
            ? overlayHeight.value + OVERLAY_BOTTOM_SAFE_PADDING
            : 24;

    return {
        paddingBottom: `${bottomPadding}px`,
    };
});

const plainText = computed(() => {
    const block = lockedBlock.value;
    const content = (block?.content ?? "").replace(/\r\n/g, "\n");
    if (!block) return content;

    const hasHighlights = highlights.value.length > 0;
    const isScriptureBlock =
        block.sourceReferenceId != null ||
        isStableNumberedScriptureMarkdown(content);
    if (!isScriptureBlock) return content;

    // Existing highlights store character offsets over the current content. Only
    // normalize offset-bearing legacy content when it is already stable; otherwise
    // preserving offsets is safer than changing what the ranges point at.
    if (hasHighlights && !isStableNumberedScriptureMarkdown(content))
        return content;
    return normalizeScriptureMarkdown(content) ?? "";
});

type Segment =
    | { kind: "text"; text: string }
    | { kind: "highlight"; id: string; text: string };

interface VerseRow {
    number: number;
    segments: Segment[];
}

interface VerseMarker {
    number: number;
    markerStart: number;
    markerEnd: number;
}

function orderedHighlightsForText(text: string): ExegesisHighlight[] {
    return [...highlights.value]
        .map((h) => ({
            ...h,
            start: Math.max(0, Math.min(h.start, text.length)),
            end: Math.max(0, Math.min(h.end, text.length)),
        }))
        .filter((h) => h.end > h.start)
        .sort((a, b) => a.start - b.start || a.end - b.end);
}

function segmentsForRange(text: string, start: number, end: number): Segment[] {
    if (!text || end <= start) return [];

    const ordered = orderedHighlightsForText(text);
    const out: Segment[] = [];
    let cursor = start;

    for (const h of ordered) {
        const overlapStart = Math.max(start, h.start);
        const overlapEnd = Math.min(end, h.end);
        if (overlapEnd <= overlapStart) continue;

        if (overlapStart > cursor) {
            out.push({ kind: "text", text: text.slice(cursor, overlapStart) });
        }
        out.push({
            kind: "highlight",
            id: h.id,
            text: text.slice(overlapStart, overlapEnd),
        });
        cursor = overlapEnd;
    }

    if (cursor < end) out.push({ kind: "text", text: text.slice(cursor, end) });
    return out.filter((segment) => segment.text.length > 0);
}

function verseMarkers(text: string): VerseMarker[] {
    const markers: VerseMarker[] = [];
    const regex = /(?:^|\n)\s*(\d{1,3})[.)]\s+/g;
    let match: RegExpExecArray | null;

    while ((match = regex.exec(text)) != null) {
        const rawNumber = match[1];
        const numberOffset = match[0].indexOf(rawNumber);
        markers.push({
            number: Number.parseInt(rawNumber, 10),
            markerStart: match.index + numberOffset,
            markerEnd: match.index + match[0].length,
        });
    }

    return markers;
}

const verseRows = computed<VerseRow[]>(() => {
    const text = plainText.value;
    const markers = verseMarkers(text);
    if (markers.length === 0) return [];

    return markers
        .map((marker, index) => {
            const next = markers[index + 1];
            let contentEnd = next ? next.markerStart : text.length;
            while (
                contentEnd > marker.markerEnd &&
                /\s/.test(text[contentEnd - 1])
            ) {
                contentEnd -= 1;
            }

            return {
                number: marker.number,
                segments: segmentsForRange(text, marker.markerEnd, contentEnd),
            };
        })
        .filter((row) => row.segments.length > 0);
});

const segments = computed<Segment[]>(() =>
    segmentsForRange(plainText.value, 0, plainText.value.length),
);

function openHighlightByIndex(idx: number) {
    if (idx < 0 || idx >= highlights.value.length) return;
    activeIndex.value = idx;
    overlayOpen.value = true;
    const h = highlights.value[idx];
    markVisited(h.id);

    nextTick(() => {
        updateOverlayHeight();
        requestAnimationFrame(() => {
            updateOverlayHeight();
            scrollToHighlight(h.id);
        });
    });
}

function openHighlightById(id: string) {
    const idx = highlights.value.findIndex((h) => h.id === id);
    if (idx === -1) return;
    openHighlightByIndex(idx);
}

function markVisited(id: string) {
    if (visited.value.has(id)) return;
    visited.value = new Set(visited.value).add(id);
    emit("visit", props.activity.id, id);
}

function updateOverlayHeight() {
    overlayHeight.value = overlayRef.value?.getBoundingClientRect().height ?? 0;
}

function topScrollInsetForContainer(container: HTMLElement): number {
    const activity = container.closest(".LessonActivity");
    const header = activity?.querySelector(
        ".LessonActivity__header",
    ) as HTMLElement | null;
    const containerRect = container.getBoundingClientRect();
    const headerRect = header?.getBoundingClientRect();
    const overlappingHeader = headerRect
        ? Math.max(0, headerRect.bottom - containerRect.top)
        : 0;

    return overlappingHeader + ACTIVE_HIGHLIGHT_TOP_PADDING;
}

function scrollToHighlight(id: string) {
    const container = containerRef.value;
    if (!container) return;
    const el = container.querySelector(
        `[data-highlight-id="${id}"]`,
    ) as HTMLElement | null;
    if (!el) return;

    const containerTop = container.getBoundingClientRect().top;
    const elTop = el.getBoundingClientRect().top;
    const targetTop = containerTop + topScrollInsetForContainer(container);
    const delta = elTop - targetTop;
    container.scrollBy({ top: delta, behavior: "smooth" });
}

function prev() {
    if (activeIndex.value == null) return;
    openHighlightByIndex(activeIndex.value - 1);
}

function next() {
    if (activeIndex.value == null) return;
    openHighlightByIndex(activeIndex.value + 1);
}

function done() {
    overlayOpen.value = false;
    activeIndex.value = null;
}

onMounted(() => {
    const initialVisited =
        props.activity.progress?.exegesisVisitedHighlightIds ?? [];
    if (Array.isArray(initialVisited)) {
        visited.value = new Set(initialVisited);
    }

    // If server already marked complete, allow Next immediately.
    if (props.activity.progress?.completedAt) {
        // Mark all highlights visited logically.
        for (const h of highlights.value) visited.value.add(h.id);
    }

    emit("complete", isComplete.value);

    // Auto-open a highlight on mount (used by capture fixtures)
    if (
        props.initialHighlightIndex != null &&
        highlights.value.length > props.initialHighlightIndex
    ) {
        nextTick(() => openHighlightByIndex(props.initialHighlightIndex!));
    }
});
</script>

<template>
    <div
        class="ExegesisStep"
        :class="{ 'ExegesisStep--fullscreen': fullScreen }"
        :style="containerStyle"
    >
        <div
            ref="containerRef"
            class="ExegesisStep__verse-container"
            :style="verseContainerStyle"
        >
            <template v-if="plainText">
                <div
                    v-if="verseRows.length > 0"
                    class="ExegesisStep__verse-list"
                >
                    <div
                        v-for="row in verseRows"
                        :key="row.number"
                        class="ExegesisStep__verse-row"
                    >
                        <span class="ExegesisStep__verse-number">{{
                            row.number
                        }}</span>
                        <span class="ExegesisStep__verse-text">
                            <span
                                v-for="(seg, i) in row.segments"
                                :key="i"
                                :class="
                                    seg.kind === 'highlight'
                                        ? [
                                              'ExegesisStep__highlight',
                                              visited.has(seg.id) &&
                                                  'ExegesisStep__highlight--visited',
                                              activeHighlight?.id === seg.id &&
                                                  'ExegesisStep__highlight--active',
                                              promptedHighlightId === seg.id &&
                                                  'ExegesisStep__highlight--prompted',
                                          ]
                                        : 'ExegesisStep__text'
                                "
                                v-bind="
                                    seg.kind === 'highlight'
                                        ? { 'data-highlight-id': seg.id }
                                        : {}
                                "
                                @click="
                                    seg.kind === 'highlight'
                                        ? openHighlightById(seg.id)
                                        : undefined
                                "
                                >{{ seg.text }}</span
                            >
                        </span>
                    </div>
                </div>
                <template v-else>
                    <span
                        v-for="(seg, i) in segments"
                        :key="i"
                        :class="
                            seg.kind === 'highlight'
                                ? [
                                      'ExegesisStep__highlight',
                                      visited.has(seg.id) &&
                                          'ExegesisStep__highlight--visited',
                                      activeHighlight?.id === seg.id &&
                                          'ExegesisStep__highlight--active',
                                      promptedHighlightId === seg.id &&
                                          'ExegesisStep__highlight--prompted',
                                  ]
                                : 'ExegesisStep__text'
                        "
                        v-bind="
                            seg.kind === 'highlight'
                                ? { 'data-highlight-id': seg.id }
                                : {}
                        "
                        @click="
                            seg.kind === 'highlight'
                                ? openHighlightById(seg.id)
                                : undefined
                        "
                        >{{ seg.text }}</span
                    >
                </template>
            </template>
            <div v-else class="ExegesisStep__empty">
                This activity is not configured yet.
            </div>
        </div>

        <!-- Bottom overlay for the active highlight note -->
        <transition name="exegesis-overlay">
            <div
                v-if="overlayOpen && activeHighlight"
                ref="overlayRef"
                class="ExegesisStep__overlay"
            >
                <div class="ExegesisStep__overlay-nav">
                    <button
                        class="ExegesisStep__nav-btn"
                        :disabled="activeIndex === 0"
                        @click="prev"
                    >
                        ‹
                    </button>
                    <button class="ExegesisStep__done-btn" @click="done">
                        Done
                    </button>
                    <button
                        class="ExegesisStep__nav-btn"
                        :disabled="activeIndex === highlights.length - 1"
                        @click="next"
                    >
                        ›
                    </button>
                </div>

                <div class="ExegesisStep__overlay-body">
                    <div class="ExegesisStep__note" v-html="activeNoteHtml" />
                </div>
            </div>
        </transition>
    </div>
</template>

<style scoped lang="scss">
.ExegesisStep {
    position: relative;
    width: 100%;
    height: 100%;
    overflow: hidden;
    color: white;
    user-select: none;
    font-family:
        "SF Pro Text",
        -apple-system,
        BlinkMacSystemFont,
        sans-serif;
}

.ExegesisStep__verse-container {
    height: 100%;
    overflow-y: auto;
    padding: 120px 16px 24px;
    line-height: 1.55;
    white-space: pre-wrap;
    -webkit-overflow-scrolling: touch;
    mask-image: linear-gradient(
        to bottom,
        transparent 0,
        transparent 32px,
        black 120px,
        black 100%
    );
    -webkit-mask-image: linear-gradient(
        to bottom,
        transparent 0,
        transparent 32px,
        black 120px,
        black 100%
    );
}

.ExegesisStep__verse-list {
    display: flex;
    flex-direction: column;
    gap: 1em;
    white-space: normal;
}

.ExegesisStep__verse-row {
    display: grid;
    grid-template-columns: 24px minmax(0, 1fr);
    column-gap: 12px;
    align-items: start;
}

.ExegesisStep__verse-number {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    margin-top: 0.06em;
    border-radius: 999px;
    color: rgba(255, 255, 255, 0.7);
    font-size: 0.8em;
    font-weight: 700;
    line-height: 1.2em;
    font-variant-numeric: tabular-nums;
}

.ExegesisStep__verse-text {
    min-width: 0;
    white-space: normal;
}

.ExegesisStep__text {
    display: inline;
    white-space: inherit;
}

.ExegesisStep__highlight {
    display: inline;
    white-space: inherit;
    background: rgba(255, 255, 255, 0.3);
    padding: 0.2em 0;
    border-radius: 2px;
    line-height: inherit;
    box-decoration-break: clone;
    -webkit-box-decoration-break: clone;
    cursor: pointer;
}

.ExegesisStep__highlight--visited {
    /* Keep highlight visible after it has been opened. */
    background: #5680ff;
}

.ExegesisStep__highlight--active {
    background: #ffffff;
    color: #111215;
}

.ExegesisStep__highlight--prompted {
    animation: exegesis-highlight-pulse 2100ms cubic-bezier(0.2, 0, 0, 1)
        infinite;
}

@keyframes exegesis-highlight-pulse {
    0%,
    100% {
        background: rgba(255, 255, 255, 0.3);
        box-shadow: 0 0 0 0 rgba(255, 255, 255, 0);
    }

    50% {
        background: rgba(255, 255, 255, 0.58);
        box-shadow: 0 0 0 0.28em rgba(255, 255, 255, 0.16);
    }
}

@media (prefers-reduced-motion: reduce) {
    .ExegesisStep__highlight--prompted {
        animation: none;
        background: rgba(255, 255, 255, 0.58);
    }
}

.ExegesisStep__empty {
    padding: 16px;
    text-align: center;
    opacity: 0.7;
}

.ExegesisStep__overlay {
    position: absolute;
    left: 0;
    right: 0;
    bottom: 0;
    max-height: 45vh;
    height: 100%;
    display: flex;
    gap: 16px;
    flex-direction: column;
    background: linear-gradient(to top, rgba(0, 0, 0, 1), rgba(0, 0, 0, 0.2));
    backdrop-filter: blur(40px);
    -webkit-backdrop-filter: blur(40px);
    padding: 16px;
}

.ExegesisStep__overlay-nav {
    display: grid;
    grid-template-columns: 44px 1fr 44px;
    align-items: center;
    gap: 8px;
}

.ExegesisStep__nav-btn {
    width: 44px;
    height: 36px;
    border: 0;
    border-radius: 10px;
    background: rgba(255, 255, 255, 0.12);
    color: white;
    font-size: 22px;
    line-height: 1;
}

.ExegesisStep__nav-btn:disabled {
    opacity: 0.35;
}

.ExegesisStep__done-btn {
    justify-self: center;
    border: 0;
    border-radius: 10px;
    height: 36px;
    padding: 0 14px;
    background: rgba(255, 255, 255, 0.12);
    color: white;
    font-size: 14px;
    font-weight: 700;
}

.ExegesisStep__overlay-body {
    flex: 1 1 0;
    overflow-y: auto;
    min-height: 0;
}

.ExegesisStep__note {
    font-size: 1.2em;
    line-height: 1.5em;
    color: #ffffff;

    :deep(p) {
        margin: 0 0 0.6em;
        &:last-child {
            margin-bottom: 0;
        }
    }

    :deep(strong) {
        font-weight: 700;
    }
    :deep(em) {
        font-style: italic;
    }

    :deep(h1),
    :deep(h2),
    :deep(h3) {
        font-weight: 700;
        margin: 0 0 0.4em;
    }
    :deep(h1) {
        font-size: 1.3em;
    }
    :deep(h2) {
        font-size: 1.15em;
    }
    :deep(h3) {
        font-size: 1em;
    }

    :deep(ul),
    :deep(ol) {
        margin: 0 0 0.6em;
        padding-left: 1.4em;
    }
    :deep(li) {
        margin-bottom: 0.25em;
    }

    :deep(blockquote) {
        margin: 0 0 0.6em;
        padding-left: 0.8em;
        border-left: 2px solid rgba(255, 255, 255, 0.3);
        color: rgba(255, 255, 255, 0.7);
    }

    :deep(code) {
        font-family: monospace;
        font-size: 0.9em;
        background: rgba(255, 255, 255, 0.1);
        padding: 0.1em 0.3em;
        border-radius: 3px;
    }

    :deep(a) {
        color: #7c9dff;
        text-decoration: underline;
    }
}

.exegesis-overlay-enter-active,
.exegesis-overlay-leave-active {
    transition:
        transform 220ms ease,
        opacity 220ms ease;
}
.exegesis-overlay-enter-from,
.exegesis-overlay-leave-to {
    transform: translateY(20px);
    opacity: 0;
}
</style>
