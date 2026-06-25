<script setup lang="ts">
import { ref, onMounted } from 'vue'

// Live token reference. Every swatch resolves its value from the real :root
// custom properties at runtime (getComputedStyle), so this story is a true
// mirror of _tokens.scss / _palette.scss / _semantic.scss — not a hardcoded copy.

const ramp = (name: string, stops: (number | string)[]) =>
  stops.map((s) => `--color-${name}-${s}`)

const semanticBg = [
  '--bg-canvas', '--bg-surface', '--bg-elevated', '--bg-section',
  '--bg-pending', '--bg-disabled', '--bg-brand-primary', '--bg-brand-subtle',
  '--bg-success-subtle', '--bg-warning-subtle', '--bg-error-subtle', '--bg-overlay',
]
const semanticFg = [
  '--fg-primary', '--fg-secondary', '--fg-tertiary', '--fg-disabled',
  '--fg-brand', '--fg-accent', '--fg-error', '--fg-warning', '--fg-success', '--fg-destructive',
]
const semanticBorder = ['--border-default', '--border-primary', '--border-strong', '--border-brand', '--border-error']

const ramps: { label: string; tokens: string[] }[] = [
  { label: 'Brand', tokens: ramp('brand', [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950]) },
  { label: 'Neutral', tokens: ramp('neutral', [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950]) },
  { label: 'Dark Neutral', tokens: ramp('dark-neutral', [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950]) },
  { label: 'Indigo', tokens: ramp('indigo', [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950]) },
  { label: 'Error', tokens: ramp('error', [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950]) },
  { label: 'Warning', tokens: ramp('warning', [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950]) },
  { label: 'Success', tokens: ramp('success', [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950]) },
]
const whiteAlpha = ['--color-white-5', '--color-white-10', '--color-white-20', '--color-white-30', '--color-white-50', '--color-white-70', '--color-white-100']

const spacing = ['--space-2xs', '--space-xs', '--space-sm', '--space-md', '--space-lg', '--space-xl', '--space-2xl', '--space-3xl']
const radius = ['--radius-sm', '--radius-md', '--radius-lg', '--radius-full']
const type = [
  { size: '--text-xs', leading: '--leading-xs' },
  { size: '--text-sm', leading: '--leading-sm' },
  { size: '--text-md', leading: '--leading-md' },
  { size: '--text-lead', leading: '--leading-lead' },
  { size: '--text-subheading', leading: '--leading-subheading' },
  { size: '--text-heading', leading: '--leading-heading' },
  { size: '--text-title', leading: '--leading-title' },
  { size: '--text-display', leading: '--leading-display' },
]
const weights = ['--font-weight-regular', '--font-weight-medium', '--font-weight-semibold', '--font-weight-bold']
const tracking = ['--tracking-tight', '--tracking-normal', '--tracking-label', '--tracking-wide']
const shadows = ['--shadow-sm', '--shadow-md', '--shadow-lg', '--shadow-xl', '--shadow-overlay']
const blurs = ['--blur-sm', '--blur-md', '--blur-lg']
const durations = ['--motion-micro-fast', '--motion-micro', '--motion-settle', '--motion-exit', '--motion-brisk', '--motion-standard']
const easings = ['--ease-standard', '--ease-enter', '--ease-exit', '--ease-spring']
const zindex = ['--z-base', '--z-dropdown', '--z-sticky', '--z-overlay', '--z-modal', '--z-popover', '--z-toast', '--z-banner']
const opacities = ['--opacity-disabled', '--opacity-pressed', '--opacity-muted', '--opacity-hover-well', '--opacity-pressed-well']
const icons = ['--icon-xs', '--icon-sm', '--icon-md', '--icon-lg']
const avatars = ['--avatar-sm', '--avatar-md', '--avatar-lg', '--avatar-xl']
const layout = ['--page-max-w', '--page-pad-x', '--gutter', '--header-h', '--tabbar-h', '--touch-min']
const safeAreas = ['--safe-top', '--safe-right', '--safe-bottom', '--safe-left']

// Resolve every referenced token once mounted, for the value labels.
const resolved = ref<Record<string, string>>({})
const playing = ref(false)
onMounted(() => {
  const cs = getComputedStyle(document.documentElement)
  const all = [
    ...semanticBg, ...semanticFg, ...semanticBorder, ...whiteAlpha,
    ...ramps.flatMap((r) => r.tokens),
    ...spacing, ...radius, ...weights, ...tracking, ...shadows, ...blurs,
    ...durations, ...easings, ...zindex, ...opacities, ...icons, ...avatars,
    ...layout, ...safeAreas, ...type.flatMap((t) => [t.size, t.leading]),
  ]
  const out: Record<string, string> = {}
  all.forEach((t) => { out[t] = cs.getPropertyValue(t).trim() })
  resolved.value = out
})
const val = (t: string) => resolved.value[t] || '—'
// Toggle to replay duration/easing demos.
const replay = () => { playing.value = false; requestAnimationFrame(() => { playing.value = true }) }
</script>

<template>
  <Story title="Foundations/Tokens" :layout="{ type: 'single' }">
    <!-- ─── Semantic colors ─────────────────────────────────────────────── -->
    <Variant title="Semantic — Backgrounds">
      <div class="Fnd">
        <h3 class="Fnd__h">Background surfaces (dark)</h3>
        <div class="Fnd__grid">
          <div v-for="t in semanticBg" :key="t" class="Fnd__sw">
            <div class="Fnd__chip" :style="{ background: `var(${t})` }" />
            <code>{{ t }}</code>
            <span class="Fnd__val">{{ val(t) }}</span>
          </div>
        </div>
      </div>
    </Variant>

    <Variant title="Semantic — Foreground & Borders">
      <div class="Fnd">
        <h3 class="Fnd__h">Foreground (text)</h3>
        <div class="Fnd__grid">
          <div v-for="t in semanticFg" :key="t" class="Fnd__sw">
            <div class="Fnd__chip Fnd__chip--text" :style="{ color: `var(${t})` }">Aa</div>
            <code>{{ t }}</code>
            <span class="Fnd__val">{{ val(t) }}</span>
          </div>
        </div>
        <h3 class="Fnd__h">Borders</h3>
        <div class="Fnd__grid">
          <div v-for="t in semanticBorder" :key="t" class="Fnd__sw">
            <div class="Fnd__chip Fnd__chip--border" :style="{ borderColor: `var(${t})` }" />
            <code>{{ t }}</code>
            <span class="Fnd__val">{{ val(t) }}</span>
          </div>
        </div>
      </div>
    </Variant>

    <!-- ─── Primitive ramps ─────────────────────────────────────────────── -->
    <Variant title="Primitive ramps">
      <div class="Fnd">
        <div v-for="r in ramps" :key="r.label" class="Fnd__ramp">
          <h3 class="Fnd__h">{{ r.label }}</h3>
          <div class="Fnd__rampRow">
            <div
              v-for="t in r.tokens"
              :key="t"
              class="Fnd__rampCell"
              :style="{ background: `var(${t})` }"
              :title="`${t} — ${val(t)}`"
            >
              <span>{{ t.split('-').pop() }}</span>
            </div>
          </div>
        </div>
        <h3 class="Fnd__h">White alpha</h3>
        <div class="Fnd__rampRow Fnd__rampRow--checker">
          <div
            v-for="t in whiteAlpha"
            :key="t"
            class="Fnd__rampCell"
            :style="{ background: `var(${t})` }"
            :title="`${t} — ${val(t)}`"
          >
            <span>{{ t.split('-').pop() }}</span>
          </div>
        </div>
      </div>
    </Variant>

    <!-- ─── Spacing & radius ────────────────────────────────────────────── -->
    <Variant title="Spacing & Radius">
      <div class="Fnd">
        <h3 class="Fnd__h">Spacing (4px base)</h3>
        <div v-for="t in spacing" :key="t" class="Fnd__bar">
          <div class="Fnd__barFill" :style="{ width: `var(${t})` }" />
          <code>{{ t }}</code><span class="Fnd__val">{{ val(t) }}</span>
        </div>
        <h3 class="Fnd__h">Radius</h3>
        <div class="Fnd__grid">
          <div v-for="t in radius" :key="t" class="Fnd__sw">
            <div class="Fnd__chip Fnd__chip--radius" :style="{ borderRadius: `var(${t})` }" />
            <code>{{ t }}</code><span class="Fnd__val">{{ val(t) }}</span>
          </div>
        </div>
      </div>
    </Variant>

    <!-- ─── Typography ──────────────────────────────────────────────────── -->
    <Variant title="Typography">
      <div class="Fnd">
        <h3 class="Fnd__h">Type scale (size / line-height)</h3>
        <div
          v-for="t in type"
          :key="t.size"
          class="Fnd__type"
          :style="{ fontSize: `var(${t.size})`, lineHeight: `var(${t.leading})` }"
        >
          The quick brown fox
          <code class="Fnd__typeMeta">{{ t.size }} · {{ val(t.size) }} / {{ val(t.leading) }}</code>
        </div>
        <h3 class="Fnd__h">Weights</h3>
        <div
          v-for="t in weights"
          :key="t"
          class="Fnd__type"
          :style="{ fontWeight: `var(${t})`, fontSize: 'var(--text-lead)' }"
        >
          Make ready · <code class="Fnd__typeMeta">{{ t }} · {{ val(t) }}</code>
        </div>
        <h3 class="Fnd__h">Tracking</h3>
        <div
          v-for="t in tracking"
          :key="t"
          class="Fnd__type Fnd__type--upper"
          :style="{ letterSpacing: `var(${t})`, fontSize: 'var(--text-sm)' }"
        >
          OVERLINE LABEL · <code class="Fnd__typeMeta">{{ t }} · {{ val(t) }}</code>
        </div>
      </div>
    </Variant>

    <!-- ─── Shadows & blur ──────────────────────────────────────────────── -->
    <Variant title="Shadows & Blur">
      <div class="Fnd">
        <h3 class="Fnd__h">Elevation</h3>
        <div class="Fnd__grid Fnd__grid--wide">
          <div v-for="t in shadows" :key="t" class="Fnd__sw">
            <div class="Fnd__chip Fnd__chip--elev" :style="{ boxShadow: `var(${t})` }" />
            <code>{{ t }}</code><span class="Fnd__val">{{ val(t) }}</span>
          </div>
        </div>
        <h3 class="Fnd__h">Blur (backdrop-filter)</h3>
        <div class="Fnd__blurStage">
          <div
            v-for="t in blurs"
            :key="t"
            class="Fnd__blurChip"
            :style="{ backdropFilter: `blur(var(${t}))`, '-webkit-backdrop-filter': `blur(var(${t}))` }"
          >
            <code>{{ t }}</code><span class="Fnd__val">{{ val(t) }}</span>
          </div>
        </div>
      </div>
    </Variant>

    <!-- ─── Motion ──────────────────────────────────────────────────────── -->
    <Variant title="Motion">
      <div class="Fnd">
        <button class="Fnd__replay" @click="replay">▶ Replay</button>
        <h3 class="Fnd__h">Durations (easeInOut)</h3>
        <div v-for="t in durations" :key="t" class="Fnd__bar">
          <div class="Fnd__track">
            <div
              class="Fnd__dot"
              :style="{ transition: `transform var(${t}) var(--ease-standard)`, transform: playing ? 'translateX(220px)' : 'translateX(0)' }"
            />
          </div>
          <code>{{ t }}</code><span class="Fnd__val">{{ val(t) }}</span>
        </div>
        <h3 class="Fnd__h">Easings (standard duration)</h3>
        <div v-for="t in easings" :key="t" class="Fnd__bar">
          <div class="Fnd__track">
            <div
              class="Fnd__dot"
              :style="{ transition: `transform var(--motion-standard) var(${t})`, transform: playing ? 'translateX(220px)' : 'translateX(0)' }"
            />
          </div>
          <code>{{ t }}</code><span class="Fnd__val">{{ val(t) }}</span>
        </div>
        <p class="Fnd__note">Honors <code>prefers-reduced-motion</code>: durations collapse to ~0 and easings drop to linear.</p>
      </div>
    </Variant>

    <!-- ─── Sizing / layout / z-index / opacity ─────────────────────────── -->
    <Variant title="Sizing & Layout">
      <div class="Fnd">
        <h3 class="Fnd__h">Icon sizes</h3>
        <div class="Fnd__inline">
          <div v-for="t in icons" :key="t" class="Fnd__sw Fnd__sw--inline">
            <div class="Fnd__square" :style="{ width: `var(${t})`, height: `var(${t})` }" />
            <code>{{ t }}</code><span class="Fnd__val">{{ val(t) }}</span>
          </div>
        </div>
        <h3 class="Fnd__h">Avatar sizes</h3>
        <div class="Fnd__inline Fnd__inline--bottom">
          <div v-for="t in avatars" :key="t" class="Fnd__sw Fnd__sw--inline">
            <div class="Fnd__circle" :style="{ width: `var(${t})`, height: `var(${t})` }" />
            <code>{{ t }}</code><span class="Fnd__val">{{ val(t) }}</span>
          </div>
        </div>
        <h3 class="Fnd__h">Opacity</h3>
        <div class="Fnd__inline">
          <div v-for="t in opacities" :key="t" class="Fnd__sw Fnd__sw--inline">
            <div class="Fnd__square Fnd__square--brand" :style="{ opacity: `var(${t})` }" />
            <code>{{ t }}</code><span class="Fnd__val">{{ val(t) }}</span>
          </div>
        </div>
        <h3 class="Fnd__h">Z-index ladder</h3>
        <table class="Fnd__table">
          <tr v-for="t in zindex" :key="t"><td><code>{{ t }}</code></td><td>{{ val(t) }}</td></tr>
        </table>
        <h3 class="Fnd__h">Layout & touch</h3>
        <table class="Fnd__table">
          <tr v-for="t in layout" :key="t"><td><code>{{ t }}</code></td><td>{{ val(t) }}</td></tr>
        </table>
        <h3 class="Fnd__h">Safe-area insets (env, 0 in preview)</h3>
        <table class="Fnd__table">
          <tr v-for="t in safeAreas" :key="t"><td><code>{{ t }}</code></td><td>{{ val(t) }}</td></tr>
        </table>
      </div>
    </Variant>
  </Story>
</template>

<style scoped>
.Fnd {
  padding: var(--space-xl);
  color: var(--fg-primary);
  font-family: 'Open Sans', -apple-system, sans-serif;
  max-width: 920px;
}
.Fnd__h {
  font-size: var(--text-sm);
  font-weight: var(--font-weight-bold);
  letter-spacing: var(--tracking-wide);
  text-transform: uppercase;
  color: var(--fg-tertiary);
  margin: var(--space-xl) 0 var(--space-md);
}
.Fnd__h:first-child { margin-top: 0; }
.Fnd__grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
  gap: var(--space-lg);
}
.Fnd__grid--wide { grid-template-columns: repeat(auto-fill, minmax(190px, 1fr)); }
.Fnd__sw { display: flex; flex-direction: column; gap: var(--space-2xs); min-width: 0; }
.Fnd__sw code { font-size: var(--text-xs); color: var(--fg-secondary); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.Fnd__val { font-size: var(--text-xs); color: var(--fg-tertiary); }
.Fnd__chip {
  height: 56px;
  border-radius: var(--radius-md);
  border: 1px solid var(--border-default);
}
.Fnd__chip--text {
  display: flex; align-items: center; justify-content: center;
  font-size: var(--text-heading); font-weight: var(--font-weight-bold);
  background: var(--bg-surface);
}
.Fnd__chip--border { background: var(--bg-surface); border-width: 3px; }
.Fnd__chip--radius { background: var(--bg-brand-primary); }
.Fnd__chip--elev { background: var(--bg-surface); }

/* ramps */
.Fnd__rampRow { display: flex; border-radius: var(--radius-md); overflow: hidden; }
.Fnd__rampRow--checker {
  background-image:
    linear-gradient(45deg, #444 25%, transparent 25%),
    linear-gradient(-45deg, #444 25%, transparent 25%),
    linear-gradient(45deg, transparent 75%, #444 75%),
    linear-gradient(-45deg, transparent 75%, #444 75%);
  background-size: 16px 16px;
  background-position: 0 0, 0 8px, 8px -8px, -8px 0;
}
.Fnd__rampCell {
  flex: 1; height: 52px;
  display: flex; align-items: flex-end; justify-content: center;
  font-size: 9px; color: var(--color-white-70); padding-bottom: 2px;
}
.Fnd__ramp { margin-bottom: var(--space-md); }

/* spacing bars */
.Fnd__bar { display: flex; align-items: center; gap: var(--space-md); margin-bottom: var(--space-sm); }
.Fnd__bar code { font-size: var(--text-xs); color: var(--fg-secondary); min-width: 130px; }
.Fnd__barFill { height: 16px; background: var(--bg-brand-primary); border-radius: var(--radius-sm); min-width: 2px; }

/* typography */
.Fnd__type { color: var(--fg-primary); margin-bottom: var(--space-sm); display: flex; align-items: baseline; gap: var(--space-md); flex-wrap: wrap; }
.Fnd__type--upper { text-transform: uppercase; }
.Fnd__typeMeta { font-size: var(--text-xs); color: var(--fg-tertiary); }

/* blur */
.Fnd__blurStage {
  position: relative; display: flex; gap: var(--space-lg); padding: var(--space-xl);
  border-radius: var(--radius-lg);
  background:
    radial-gradient(circle at 20% 30%, var(--color-brand-500), transparent 45%),
    radial-gradient(circle at 80% 70%, var(--color-accent), transparent 45%),
    var(--bg-section);
}
.Fnd__blurChip {
  flex: 1; padding: var(--space-lg); border-radius: var(--radius-md);
  background: var(--color-white-10); border: 1px solid var(--border-default);
  display: flex; flex-direction: column; gap: var(--space-2xs);
}
.Fnd__blurChip code { font-size: var(--text-xs); }

/* motion */
.Fnd__replay {
  background: var(--bg-brand-primary); color: var(--fg-white); border: 0;
  padding: var(--space-xs) var(--space-md); border-radius: var(--radius-full);
  font-size: var(--text-xs); cursor: pointer; margin-bottom: var(--space-md);
}
.Fnd__track { width: 252px; height: 24px; background: var(--color-white-5); border-radius: var(--radius-full); position: relative; }
.Fnd__dot { width: 24px; height: 24px; border-radius: var(--radius-full); background: var(--bg-brand-primary); }
.Fnd__note { font-size: var(--text-xs); color: var(--fg-tertiary); margin-top: var(--space-md); }

/* sizing */
.Fnd__inline { display: flex; gap: var(--space-xl); flex-wrap: wrap; align-items: flex-start; }
.Fnd__inline--bottom { align-items: flex-end; }
.Fnd__sw--inline { align-items: center; }
.Fnd__square { background: var(--fg-secondary); border-radius: var(--radius-sm); }
.Fnd__square--brand { background: var(--bg-brand-primary); width: 48px; height: 48px; }
.Fnd__circle { background: var(--bg-brand-primary); border-radius: var(--radius-full); }

/* tables */
.Fnd__table { border-collapse: collapse; font-size: var(--text-sm); }
.Fnd__table td { padding: var(--space-2xs) var(--space-lg) var(--space-2xs) 0; color: var(--fg-secondary); }
.Fnd__table code { color: var(--fg-primary); }
</style>
