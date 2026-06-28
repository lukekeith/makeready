/**
 * Adapter: BackgroundSwatch (component comparison).
 *
 * Projects one canonical background-swatch description into:
 *   - toClient → background-swatch.vue via the ComponentCapture island
 *   - toIphone → BackgroundSwatch.swift via the component.BackgroundSwatch case
 *
 * PARITY NOTE: in the isolated snapshot the iPhone's AsyncImage never resolves the
 * remote URL, so every image variant falls back to Color.appBackground. The web
 * twin reproduces that fallback, so this adapter OMITS the image URL on the client
 * side and instead forwards `hasImage` so the color overlay still uses the correct
 * opacity (overlayOpacity when an image is configured, 1.0 for color-only).
 */
export default {
  toClient(shared) {
    const { imageUrl, color, overlayOpacity } = shared ?? {};
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop to the component wrapper (component + 16px gutters), matching
      // the iPhone sizeThatFits snapshot.
      clip: '.capture-wrap',
      data: {
        component: 'BackgroundSwatch',
        componentProps: {
          // Omit the actual image — the iPhone snapshot shows the appBackground
          // fallback, not the remote photo. Forward `hasImage` so the overlay
          // opacity matches the iOS `imageUrl == nil ? 1.0 : overlayOpacity`.
          hasImage: !!imageUrl,
          color: color ?? null,
          ...(overlayOpacity != null ? { overlayOpacity } : {}),
        },
      },
    };
  },

  toIphone(shared) {
    // Forward the canonical shape unchanged.
    return {
      platform: 'iphone',
      view: 'component.BackgroundSwatch',
      state: { component: shared },
    };
  },
};
