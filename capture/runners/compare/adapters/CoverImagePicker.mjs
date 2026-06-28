/**
 * Adapter: CoverImagePicker (component comparison, two-sided twin).
 *
 * Projects one canonical cover-image-picker description into:
 *   - toClient → cover-image-picker.vue via the ComponentCapture island
 *   - toIphone → CoverImagePicker.swift via the component.CoverImagePicker case
 *
 * PARITY NOTE: in the isolated snapshot the iOS AsyncImage never resolves the
 * remote cover URL, so a configured image renders the white@0.1 placeholder well
 * (not the photo). The web twin reproduces that placeholder, so this adapter
 * OMITS the image URL on the client side and instead forwards `hasImage` so the
 * twin picks the correct well opacity and text branch (same approach as
 * BackgroundSwatch / BlockStyleEditor).
 */
export default {
  toClient(shared = {}) {
    const { mode, programName, programDescription, existingImageUrl } = shared;
    return {
      platform: 'client',
      view: 'components.component-capture',
      // Tight-crop to the component wrapper (component + 16px gutters), matching
      // the iPhone sizeThatFits snapshot.
      clip: '.capture-wrap',
      data: {
        component: 'CoverImagePicker',
        componentProps: {
          mode: mode ?? 'editable',
          programName: programName ?? '',
          programDescription: programDescription ?? '',
          // Omit the actual image — the iPhone snapshot shows the white@0.1
          // placeholder well, not the remote photo. Forward `hasImage` so the
          // twin's well opacity + text branch match the iOS `existingImageUrl`
          // path.
          hasImage: existingImageUrl != null && existingImageUrl !== '',
        },
      },
    };
  },

  toIphone(shared = {}) {
    // Forward the canonical shape unchanged.
    return {
      platform: 'iphone',
      view: 'component.CoverImagePicker',
      state: { component: shared },
    };
  },
};
