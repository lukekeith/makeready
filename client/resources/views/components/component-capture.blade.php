{{-- resources/views/components/component-capture.blade.php --}}
{{-- Capture-only harness: renders ONE design-system component in isolation on
     the app canvas, fed arbitrary props, so the Compare tool can screenshot it
     apples-to-apples against the iPhone build. Driven by CaptureController from
     a compare fixture: data = { component, componentProps }. --}}
@php
    $component       = $component       ?? 'CardStudy';
    $componentProps  = $componentProps  ?? [];
    $live            = $live            ?? false;
@endphp
<!DOCTYPE html>
<html lang="en" class="dark">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $component }} — Component Capture</title>
    @vite(['resources/css/app.scss', 'resources/js/app.js'])
    <style>
        html, body { margin: 0; background: #0d101a; }
        /* 16px gutter on each side mirrors the iPhone component snapshot, so the
           component renders at the same intrinsic width (viewport − 32) on both. */
        .capture-wrap { display: flex; justify-content: center; padding: 16px; }
        .capture-wrap > * { width: 100%; }
    </style>
</head>
<body>
    <div class="capture-wrap">
        <div
            data-vue="ComponentCapture"
            data-props='@json(['component' => $component, 'props' => $componentProps], JSON_HEX_APOS | JSON_HEX_QUOT)'
        ></div>
    </div>
    @if ($live)
    {{-- Live-iframe mode: report the rendered height to the Compare parent so it
         can size the iframe to the component and pan/zoom the real DOM. Also
         answers element-inspect requests so a pin can resolve to the exact DOM
         element (BEM class + computed styles) under the cursor. --}}
    <script>
        (function () {
            const wrap = document.querySelector('.capture-wrap');
            if (!wrap) return;
            let last = 0;
            const post = () => {
                const h = Math.ceil(wrap.getBoundingClientRect().height);
                const w = Math.ceil(wrap.getBoundingClientRect().width);
                if (h && h !== last) {
                    last = h;
                    parent.postMessage({ type: 'capture-size', width: w, height: h }, '*');
                }
            };
            new ResizeObserver(post).observe(wrap);
            window.addEventListener('load', post);
            // Islands mount async — nudge a few times after first paint.
            [50, 200, 600, 1200].forEach((t) => setTimeout(post, t));

            // ── Element inspection (drives precise comment targeting) ──
            const STYLE_KEYS = [
                'borderRadius', 'borderTopLeftRadius', 'borderTopRightRadius',
                'borderBottomRightRadius', 'borderBottomLeftRadius',
                'padding', 'margin', 'width', 'height', 'backgroundColor', 'color',
                'fontSize', 'fontWeight', 'lineHeight', 'letterSpacing',
                'borderWidth', 'borderStyle', 'borderColor', 'boxShadow',
                'display', 'gap', 'flexDirection', 'alignItems', 'justifyContent',
                'textAlign', 'opacity',
            ];
            const isBem = (c) => c.includes('__') || /^[A-Z][A-Za-z0-9]+$/.test(c);
            const bestClass = (node) => {
                const cls = (typeof node.className === 'string'
                    ? node.className
                    : (node.getAttribute && node.getAttribute('class')) || '').trim();
                if (!cls) return null;
                const parts = cls.split(/\s+/);
                return parts.find((c) => c.includes('__') && !c.includes('--'))
                    || parts.find((c) => c.includes('__'))
                    || parts.find((c) => /^[A-Z][A-Za-z0-9]+$/.test(c))
                    || null;
            };
            const meaningful = (node) => {
                const cls = (typeof node.className === 'string' ? node.className : '') || '';
                return cls.split(/\s+/).some(isBem);
            };

            let hl = null;
            const showHighlight = (r) => {
                if (!hl) {
                    hl = document.createElement('div');
                    hl.style.cssText = 'position:fixed;pointer-events:none;z-index:2147483647;'
                        + 'border:1.5px solid #4ade80;background:rgba(74,222,128,0.12);'
                        + 'border-radius:3px;transition:all .05s linear;';
                    document.body.appendChild(hl);
                }
                hl.style.display = 'block';
                hl.style.left = r.left + 'px';
                hl.style.top = r.top + 'px';
                hl.style.width = r.width + 'px';
                hl.style.height = r.height + 'px';
            };
            const hideHighlight = () => { if (hl) hl.style.display = 'none'; };

            const describe = (x, y) => {
                const el = document.elementFromPoint(x, y);
                if (!el) return null;
                let node = el;
                while (node && node !== document.body && !meaningful(node)) node = node.parentElement;
                const target = (node && node !== document.body) ? node : el;
                const r = target.getBoundingClientRect();
                const wrapRect = wrap.getBoundingClientRect();
                const cs = getComputedStyle(target);
                const styles = {};
                for (const k of STYLE_KEYS) styles[k] = cs[k];
                const leaf = bestClass(target);
                return {
                    rect: r,
                    payload: {
                        selector: leaf ? '.' + leaf : target.tagName.toLowerCase(),
                        label: leaf || target.tagName.toLowerCase(),
                        tag: target.tagName.toLowerCase(),
                        text: (target.textContent || '').trim().slice(0, 60),
                        rect: {
                            x: (r.left - wrapRect.left) / wrapRect.width,
                            y: (r.top - wrapRect.top) / wrapRect.height,
                            w: r.width / wrapRect.width,
                            h: r.height / wrapRect.height,
                        },
                        styles,
                    },
                };
            };

            window.addEventListener('message', (e) => {
                const m = e.data;
                if (!m || typeof m !== 'object') return;
                if (m.type === 'capture-inspect') {
                    const d = describe(m.x, m.y);
                    if (d) { showHighlight(d.rect); }
                    else { hideHighlight(); }
                    parent.postMessage({ type: 'capture-inspected', reqId: m.reqId, target: d ? d.payload : null }, '*');
                } else if (m.type === 'capture-inspect-clear') {
                    hideHighlight();
                }
            });
        })();
    </script>
    @endif
</body>
</html>
