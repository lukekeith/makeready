/**
 * Where is the caret, and where should a popup that follows it go?
 *
 * The note composer's `@` typeahead used to sit at a fixed corner of the pad,
 * which put it directly over the first line — the moment you typed `@` you could
 * no longer see what you were typing. It has to hang off the token instead.
 *
 * A textarea exposes no caret geometry, so `caretCoordinates` uses the standard
 * mirror-div measurement: a hidden div that copies every property which decides
 * where a glyph lands, filled with the text up to the token and a marker span at
 * it. The marker's offset inside the mirror IS the token's offset inside the
 * textarea. `placeTypeahead` is the pure half — flip and clamp — so the part that
 * is easy to get subtly wrong can be tested without a DOM.
 */

/** Everything that affects line breaking and glyph position. Missing one (say
 *  `letterSpacing`) puts the mirror's text on a different line than the real
 *  one, which is a drift you only notice on long notes. */
const MIRROR_PROPS = [
  'boxSizing', 'width',
  'borderTopWidth', 'borderRightWidth', 'borderBottomWidth', 'borderLeftWidth',
  'paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft',
  'fontStyle', 'fontVariant', 'fontWeight', 'fontStretch', 'fontSize', 'fontFamily',
  'lineHeight', 'letterSpacing', 'wordSpacing', 'textTransform', 'textIndent',
  'textAlign', 'whiteSpace', 'wordWrap', 'wordBreak', 'tabSize',
];

/**
 * The caret's box inside `el`, in pixels relative to `el`'s OFFSET PARENT — the
 * same space an absolutely-positioned popup next to the textarea is laid out in.
 *
 * @param {HTMLTextAreaElement} el
 * @param {number} index  character offset to measure at
 * @returns {{ top: number, left: number, height: number }}
 */
export function caretCoordinates(el, index) {
  const doc = el.ownerDocument;
  const cs = doc.defaultView.getComputedStyle(el);

  const mirror = doc.createElement('div');
  MIRROR_PROPS.forEach((p) => { mirror.style[p] = cs[p]; });
  mirror.style.position = 'absolute';
  mirror.style.top = '0';
  mirror.style.left = '-9999px';
  mirror.style.visibility = 'hidden';
  // The mirror GROWS instead of scrolling: it has to lay every line out for the
  // marker's offset to mean anything. The real element's scroll is subtracted
  // below instead.
  mirror.style.height = 'auto';
  mirror.style.overflow = 'hidden';
  mirror.style.whiteSpace = 'pre-wrap';
  mirror.style.wordWrap = 'break-word';

  mirror.textContent = el.value.slice(0, index);
  const marker = doc.createElement('span');
  // A trailing empty string collapses and the marker reports the wrong line, so
  // the rest of the text (or a stand-in) always follows it.
  marker.textContent = el.value.slice(index) || '.';
  mirror.appendChild(marker);
  doc.body.appendChild(mirror);

  const top = marker.offsetTop;
  const left = marker.offsetLeft;
  doc.body.removeChild(mirror);

  const height = parseFloat(cs.lineHeight) || parseFloat(cs.fontSize) * 1.2;
  return {
    // `offsetTop/Left` position the textarea inside the popup's containing block;
    // `scrollTop/Left` account for a note long enough to have scrolled.
    top: el.offsetTop + top - el.scrollTop,
    left: el.offsetLeft + left - el.scrollLeft,
    height,
  };
}

/**
 * Turn a caret box into the popup's inline style.
 *
 * BELOW the caret line is the whole point, so it is preferred and only given up
 * when there is genuinely less room there than above. Whichever side wins, the
 * popup is capped to the room it actually has rather than being allowed to run
 * off the pad — `maxHeight` makes it scroll instead.
 *
 * Both `top` and `bottom` are always returned (one of them `'auto'`): the
 * stylesheet sets a default `top`, and leaving it in place while anchoring by
 * `bottom` would stretch the popup across the whole pad.
 *
 * @param {{top:number,left:number,height:number}} caret  from caretCoordinates
 * @param {{width:number,height:number}} box  the popup's containing block
 */
export function placeTypeahead(caret, box, opts = {}) {
  const { menuWidth = 220, gap = 4, margin = 8, minHeight = 96, maxHeight = 220 } = opts;
  const caretBottom = caret.top + caret.height;
  const roomBelow = box.height - caretBottom - gap - margin;
  const roomAbove = caret.top - gap - margin;
  // Never past the right edge, never negative — a popup half off the pad is
  // worse than one that has shifted a little from the token.
  const left = Math.max(0, Math.min(caret.left, box.width - menuWidth - margin));

  if (roomBelow >= Math.min(minHeight, maxHeight) || roomBelow >= roomAbove) {
    return {
      top: caretBottom + gap,
      bottom: 'auto',
      left,
      maxHeight: Math.max(0, Math.min(maxHeight, roomBelow)),
    };
  }
  return {
    top: 'auto',
    bottom: box.height - caret.top + gap,
    left,
    maxHeight: Math.max(0, Math.min(maxHeight, roomAbove)),
  };
}
