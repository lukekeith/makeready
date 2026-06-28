/**
 * BlockStyleEditor adapter (two-sided twin).
 *
 * iPhone side — BlockStyleEditor is a *connected* component: it reads its
 * background image / color / overlay / font-size out of
 * `AppState.shared.activities[activityId]`'s matching read block (it takes only
 * `activityId`/`blockId`, not the data). So this projects the variant's `shared`
 * block into a `state.activity` with one read block — which `setupCaptureState`
 * seeds into AppState before render (same path the edit-read-activity page uses) —
 * plus a small `component` bag for the title and theme options the editor takes as
 * init params.
 *
 * Client side — projects the same `shared` block into the block-style-editor.vue
 * twin via the ComponentCapture island. PARITY NOTE: the iOS AsyncImage never
 * resolves the remote URL in the isolated snapshot, so the configured-image variant
 * renders an EMPTY well; the adapter therefore omits the URL and forwards `hasImage`
 * so the twin reproduces that empty well (same approach as BackgroundSwatch). The
 * theme picker only ever shows "No Theme" in the snapshot (no themeId is seeded), so
 * the client gets a boolean + the static label/value rather than the option list.
 */
const ACTIVITY_ID = 'capture-bse-activity';
const BLOCK_ID = 'capture-bse-block';

export default {
  toClient(shared = {}) {
    const hasThemes = Array.isArray(shared.availableThemes) && shared.availableThemes.length > 0;
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop the web shot to the component wrapper so it matches the iPhone
      // sizeThatFits snapshot (both = component + 16px gutters).
      clip: '.capture-wrap',
      data: {
        component: 'BlockStyleEditor',
        componentProps: {
          blockTitle: shared.blockTitle ?? '',
          // Omit the actual image — the iPhone snapshot shows an empty well (the
          // AsyncImage never resolves), so forward only whether one is configured.
          hasImage: !!shared.backgroundImageUrl,
          backgroundColor: shared.backgroundColor ?? null,
          selectedSize: shared.selectedSize ?? 'm',
          showThemePicker: hasThemes,
          themeLabel: 'Theme',
          themeValue: 'No Theme',
        },
      },
    };
  },

  toIphone(shared = {}) {
    return {
      platform: 'iphone',
      view: 'component.BlockStyleEditor',
      state: {
        activity: {
          id: ACTIVITY_ID,
          type: 'READ',
          status: 'PENDING',
          readBlocks: [
            {
              id: BLOCK_ID,
              orderNumber: 0,
              isLocked: false,
              backgroundColor: shared.backgroundColor ?? null,
              backgroundImageUrl: shared.backgroundImageUrl ?? null,
              backgroundOverlayOpacity: shared.backgroundOverlayOpacity ?? null,
              fontSize: shared.selectedSize ?? 'm',
            },
          ],
        },
        component: {
          blockTitle: shared.blockTitle ?? null,
          availableThemes: shared.availableThemes ?? null,
        },
      },
    };
  },
};
