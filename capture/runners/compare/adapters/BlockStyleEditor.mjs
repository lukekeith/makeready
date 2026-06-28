/**
 * BlockStyleEditor adapter (iPhone-only).
 *
 * BlockStyleEditor is a *connected* component: it reads its background image /
 * color / overlay / font-size out of `AppState.shared.activities[activityId]`'s
 * matching read block (it takes only `activityId`/`blockId`, not the data). So
 * instead of the generic component passthrough, this adapter projects the
 * variant's `shared` block into a `state.activity` with one read block — which
 * `setupCaptureState` seeds into AppState before render (same path the
 * edit-read-activity page uses) — plus a small `component` bag for the title and
 * theme options the editor takes as init params.
 */
const ACTIVITY_ID = 'capture-bse-activity';
const BLOCK_ID = 'capture-bse-block';

export default {
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
  // No Vue twin yet.
  toClient() {
    return null;
  },
};
