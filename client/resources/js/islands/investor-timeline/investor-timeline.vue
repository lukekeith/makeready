<script setup lang="ts">
import { computed, ref } from 'vue'
import timeline from './timeline-data.json'
import './investor-timeline.scss'

interface Epic {
  id: string
  name: string
  lane: string
  start: string
  end: string
  status: 'done' | 'in-progress' | 'planned' | 'proposed'
  commits?: number
  weeks?: number
  description: string
  deliverables?: string[]
  dependsOn?: string[]
  userStories?: string[]
  tokens?: { processedM: number; outputM: number; extraCostUsd: number }
}

interface Lane {
  id: string
  name: string
  color: string
}

const lanes = timeline.lanes as Lane[]
const epics = timeline.epics as Epic[]
const meta = timeline.meta

const DAY = 24 * 60 * 60 * 1000
const TODAY = meta.generated

function toDate(s: string): Date {
  return new Date(`${s}T00:00:00`)
}

const rangeStart = computed(() => {
  const min = epics.reduce((m, e) => (e.start < m ? e.start : m), epics[0].start)
  const d = toDate(min)
  return new Date(d.getFullYear(), d.getMonth(), 1)
})

const rangeEnd = computed(() => {
  const max = epics.reduce((m, e) => (e.end > m ? e.end : m), epics[0].end)
  const d = toDate(max)
  return new Date(d.getFullYear(), d.getMonth() + 1, 1)
})

const totalDays = computed(() => (rangeEnd.value.getTime() - rangeStart.value.getTime()) / DAY)

const months = computed(() => {
  const out: { key: string; label: string; year: string; widthPct: number; isYearStart: boolean }[] = []
  const cur = new Date(rangeStart.value)
  while (cur < rangeEnd.value) {
    const next = new Date(cur.getFullYear(), cur.getMonth() + 1, 1)
    const days = (Math.min(next.getTime(), rangeEnd.value.getTime()) - cur.getTime()) / DAY
    out.push({
      key: `${cur.getFullYear()}-${cur.getMonth()}`,
      label: cur.toLocaleDateString('en-US', { month: 'short' }),
      year: String(cur.getFullYear()),
      widthPct: (days / totalDays.value) * 100,
      isYearStart: cur.getMonth() === 0,
    })
    cur.setMonth(cur.getMonth() + 1)
  }
  return out
})

function pctFor(dateStr: string): number {
  return ((toDate(dateStr).getTime() - rangeStart.value.getTime()) / DAY / totalDays.value) * 100
}

function barStyle(epic: Epic) {
  const left = pctFor(epic.start)
  const width = Math.max(pctFor(epic.end) - left, 0.6)
  const lane = lanes.find((l) => l.id === epic.lane)
  return {
    left: `${left}%`,
    width: `${width}%`,
    '--bar-color': lane ? lane.color : '#888',
  }
}

const todayPct = computed(() => pctFor(TODAY))

type FilterKey = 'all' | 'done' | 'in-progress' | 'planned' | 'proposed'
const filter = ref<FilterKey>('all')
const filters: { key: FilterKey; label: string }[] = [
  { key: 'all', label: 'Everything' },
  { key: 'done', label: 'Shipped' },
  { key: 'in-progress', label: 'In progress' },
  { key: 'planned', label: 'Next 12 months' },
  { key: 'proposed', label: 'Proposed' },
]

const visibleLanes = computed(() =>
  lanes
    .map((lane) => ({
      lane,
      epics: epics
        .filter((e) => e.lane === lane.id)
        .filter((e) => filter.value === 'all' || e.status === filter.value)
        .sort((a, b) => a.start.localeCompare(b.start)),
    }))
    .filter((g) => g.epics.length > 0)
)

const selected = ref<Epic | null>(null)

function select(epic: Epic) {
  selected.value = selected.value?.id === epic.id ? null : epic
}

function epicName(id: string): string {
  return epics.find((e) => e.id === id)?.name ?? id
}

function fmtDate(s: string): string {
  return toDate(s).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
}

function fmtMoney(n: number): string {
  return `$${n.toLocaleString('en-US')}`
}

function fmtTokens(m: number): string {
  return m >= 1000 ? `${(m / 1000).toFixed(1)}B` : `${m}M`
}

const statusLabels: Record<Epic['status'], string> = {
  done: 'Shipped',
  'in-progress': 'In progress',
  planned: 'Planned (committed)',
  proposed: 'Proposed',
}

const kpis = computed(() => [
  { value: meta.velocity.totalCommits.toLocaleString('en-US'), label: 'commits in 8 months' },
  { value: String(meta.velocity.completedEpics), label: 'epics shipped' },
  { value: String(meta.velocity.commitsPerMonth), label: 'commits / month' },
  { value: '1 dev + AI', label: 'entire team' },
])

const plannedEpics = computed(() => epics.filter((e) => e.status === 'planned'))
const plannedCost = computed(() => plannedEpics.value.reduce((s, e) => s + (e.tokens?.extraCostUsd ?? 0), 0))

const budgetScenarios = [
  { name: 'Conservative', share: '10% Fable 5', month: 520 },
  { name: 'Measured mix', share: '31% Fable 5 — as observed', month: 1465, recommended: true },
  { name: 'Aggressive', share: '50% Fable 5', month: 2610 },
]
</script>

<template>
  <div class="InvestorTimeline">
    <header class="InvestorTimeline__header">
      <p class="InvestorTimeline__eyebrow">MakeReady &middot; Confidential</p>
      <h1 class="InvestorTimeline__title">Product Development Timeline</h1>
      <p class="InvestorTimeline__subtitle">
        Everything shipped since October 2025 — measured from {{ meta.velocity.totalCommits.toLocaleString('en-US') }} commits —
        and the committed 12-month roadmap through June 2027. Click any bar for the full story.
      </p>
      <div class="InvestorTimeline__kpis">
        <div v-for="kpi in kpis" :key="kpi.label" class="InvestorTimeline__kpi">
          <span class="InvestorTimeline__kpiValue">{{ kpi.value }}</span>
          <span class="InvestorTimeline__kpiLabel">{{ kpi.label }}</span>
        </div>
      </div>
    </header>

    <div class="InvestorTimeline__controls">
      <button
        v-for="f in filters"
        :key="f.key"
        class="InvestorTimeline__chip"
        :class="{ 'InvestorTimeline__chip--active': filter === f.key }"
        type="button"
        @click="filter = f.key"
      >
        {{ f.label }}
      </button>
      <div class="InvestorTimeline__legend">
        <span class="InvestorTimeline__legendItem InvestorTimeline__legendItem--done">Shipped</span>
        <span class="InvestorTimeline__legendItem InvestorTimeline__legendItem--progress">In progress</span>
        <span class="InvestorTimeline__legendItem InvestorTimeline__legendItem--planned">Committed</span>
        <span class="InvestorTimeline__legendItem InvestorTimeline__legendItem--proposed">Proposed</span>
      </div>
    </div>

    <div class="InvestorTimeline__layout" :class="{ 'InvestorTimeline__layout--detail': selected }">
      <div class="InvestorTimeline__ganttWrap">
        <div class="InvestorTimeline__gantt">
          <div class="InvestorTimeline__axis">
            <div class="InvestorTimeline__axisLabel"></div>
            <div class="InvestorTimeline__axisMonths">
              <div
                v-for="m in months"
                :key="m.key"
                class="InvestorTimeline__month"
                :class="{ 'InvestorTimeline__month--year': m.isYearStart }"
                :style="{ width: `${m.widthPct}%` }"
              >
                <span>{{ m.label }}</span>
                <em v-if="m.isYearStart || m.key.endsWith('-10')">{{ m.year }}</em>
              </div>
            </div>
          </div>

          <template v-for="group in visibleLanes" :key="group.lane.id">
            <div class="InvestorTimeline__laneHeader">
              <span class="InvestorTimeline__laneDot" :style="{ background: group.lane.color }"></span>
              {{ group.lane.name }}
              <span class="InvestorTimeline__laneCount">{{ group.epics.length }}</span>
            </div>
            <div
              v-for="epic in group.epics"
              :key="epic.id"
              class="InvestorTimeline__row"
              :class="{ 'InvestorTimeline__row--selected': selected?.id === epic.id }"
              @click="select(epic)"
            >
              <div class="InvestorTimeline__rowLabel" :title="epic.name">{{ epic.name }}</div>
              <div class="InvestorTimeline__rowTrack">
                <div class="InvestorTimeline__gridlines">
                  <span
                    v-for="m in months"
                    :key="m.key"
                    :style="{ width: `${m.widthPct}%` }"
                    :class="{ 'InvestorTimeline__gridline--year': m.isYearStart }"
                  ></span>
                </div>
                <div class="InvestorTimeline__today" :style="{ left: `${todayPct}%` }"></div>
                <button
                  class="InvestorTimeline__bar"
                  :class="`InvestorTimeline__bar--${epic.status}`"
                  :style="barStyle(epic)"
                  type="button"
                  :aria-label="`${epic.name}: ${fmtDate(epic.start)} to ${fmtDate(epic.end)}`"
                >
                  <span class="InvestorTimeline__barMeta">
                    {{ epic.commits ? `${epic.commits} commits` : epic.weeks ? `${epic.weeks} wks` : '' }}
                  </span>
                </button>
              </div>
            </div>
          </template>
        </div>
      </div>

      <aside v-if="selected" class="InvestorTimeline__detail">
        <button class="InvestorTimeline__detailClose" type="button" @click="selected = null">&times;</button>
        <span class="InvestorTimeline__detailStatus" :class="`InvestorTimeline__detailStatus--${selected.status}`">
          {{ statusLabels[selected.status] }}
        </span>
        <h2 class="InvestorTimeline__detailTitle">{{ selected.name }}</h2>
        <p class="InvestorTimeline__detailDates">
          {{ fmtDate(selected.start) }} &rarr; {{ fmtDate(selected.end) }}
          <template v-if="selected.commits"> &middot; {{ selected.commits }} commits</template>
          <template v-else-if="selected.weeks"> &middot; est. {{ selected.weeks }} weeks</template>
        </p>
        <p class="InvestorTimeline__detailDesc">{{ selected.description }}</p>

        <template v-if="selected.deliverables?.length">
          <h3 class="InvestorTimeline__detailHeading">{{ selected.status === 'done' ? 'Delivered' : 'Scope' }}</h3>
          <ul class="InvestorTimeline__detailList">
            <li v-for="d in selected.deliverables" :key="d">{{ d }}</li>
          </ul>
        </template>

        <template v-if="selected.dependsOn?.length">
          <h3 class="InvestorTimeline__detailHeading">Depends on</h3>
          <p class="InvestorTimeline__detailText">
            {{ selected.dependsOn.map(epicName).join(', ') }}
          </p>
        </template>

        <template v-if="selected.userStories?.length">
          <h3 class="InvestorTimeline__detailHeading">Original user stories served</h3>
          <p class="InvestorTimeline__detailText">{{ selected.userStories.join(' · ') }}</p>
        </template>

        <template v-if="selected.tokens">
          <h3 class="InvestorTimeline__detailHeading">AI development budget</h3>
          <div class="InvestorTimeline__tokenGrid">
            <div>
              <strong>{{ fmtTokens(selected.tokens.processedM) }}</strong>
              <span>input tokens processed</span>
            </div>
            <div>
              <strong>{{ fmtTokens(selected.tokens.outputM) }}</strong>
              <span>output tokens</span>
            </div>
            <div>
              <strong>{{ fmtMoney(selected.tokens.extraCostUsd) }}</strong>
              <span>extra tokens (Fable 5)</span>
            </div>
          </div>
        </template>
      </aside>
    </div>

    <section class="InvestorTimeline__budget">
      <h2 class="InvestorTimeline__sectionTitle">AI Token Budget</h2>
      <p class="InvestorTimeline__sectionSub">
        Development runs on Claude Code. The $200/mo Max plan covers Opus 4.8 for routine implementation;
        Claude Fable 5 (architecture, hardest debugging, long autonomous runs) bills as extra tokens from July 7, 2026.
        The 12-month plan needs <strong>{{ fmtMoney(plannedCost) }}</strong> of extra tokens at the recommended mix.
      </p>
      <div class="InvestorTimeline__scenarios">
        <div
          v-for="s in budgetScenarios"
          :key="s.name"
          class="InvestorTimeline__scenario"
          :class="{ 'InvestorTimeline__scenario--recommended': s.recommended }"
        >
          <span class="InvestorTimeline__scenarioName">{{ s.name }}</span>
          <span class="InvestorTimeline__scenarioValue">{{ fmtMoney(s.month) }}<em>/mo</em></span>
          <span class="InvestorTimeline__scenarioShare">{{ s.share }}</span>
          <span v-if="s.recommended" class="InvestorTimeline__scenarioBadge">Recommended budget: $1,500/mo</span>
        </div>
      </div>
      <p class="InvestorTimeline__footnote">
        Measured from actual Claude Code session logs (Jun 11 &ndash; Jul 5, 2026; 13,501 messages):
        ~800M input tokens processed per dev-week, 97.4% served from prompt cache, ~3.1M output.
        Full methodology in <code>docs/future/token-budget.md</code>.
      </p>
    </section>

    <footer class="InvestorTimeline__footer">
      Generated {{ fmtDate(meta.generated) }} from complete git history &middot; MakeReady
    </footer>
  </div>
</template>
