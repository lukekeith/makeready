/**
 * PNG dimensions from the IHDR header, without decoding the image.
 *
 * Moved out of server.mjs (component-browser era) so the UI 2.0 screen index can
 * use it too: `buildUi2Screens()` needs a snapshot's real pixel size to run the
 * element map's aspect-ratio guard, and it runs in lib/ with no access to the
 * server module (docs/features/ui2-component-notes/09 §G-3).
 *
 * Every PNG starts with an 8-byte signature followed by the IHDR chunk, whose
 * width and height are big-endian uint32s at bytes 16 and 20. 24 bytes is
 * therefore the whole read.
 */
import fs from 'node:fs/promises';

export async function pngSize(abs) {
  try {
    const fh = await fs.open(abs, 'r');
    try {
      const buf = Buffer.alloc(24);
      await fh.read(buf, 0, 24, 0);
      if (buf.toString('ascii', 1, 4) !== 'PNG') return {};
      return { width: buf.readUInt32BE(16), height: buf.readUInt32BE(20) };
    } finally { await fh.close(); }
  } catch { return {}; }
}
