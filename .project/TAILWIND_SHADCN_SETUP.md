# Tailwind + shadcn/ui Setup Guide

This document captures the **complete, working configuration** for Tailwind CSS + shadcn/ui integration in this monorepo. Follow these steps exactly to avoid setup issues.

## Critical Success Factors

The key to getting Tailwind + shadcn working correctly:

1. **HSL format for CSS variables** (not hex)
2. **Inline Tailwind config in Storybook** (not external file)
3. **PostCSS processing in Storybook Vite config**
4. **SVGR plugin for SVG imports**
5. **Correct content paths for all workspace folders**

---

## 1. Install Dependencies

### Root Package Dependencies

```bash
# Root package.json devDependencies
npm install -D \
  concurrently \
  typescript \
  vite-plugin-svgr
```

### Project-Level Dependencies

```bash
# Install at root level (not in workspace)
npm install \
  tailwindcss \
  postcss \
  autoprefixer \
  tailwindcss-animate \
  tailwind-merge \
  class-variance-authority \
  clsx \
  mobx \
  mobx-react \
  lucide-react
```

### Storybook Dependencies

```bash
# Storybook 8.6.14 with React + Vite
npm install -D \
  @storybook/react-vite@8.6.14 \
  @storybook/react@8.6.14 \
  @storybook/addon-links@8.6.14 \
  @storybook/addon-essentials@8.6.14 \
  @storybook/addon-interactions@8.6.14 \
  @storybook/addon-themes@8.6.14 \
  @storybook/blocks@8.6.14 \
  @storybook/test@8.6.14
```

**IMPORTANT:** Storybook addons must match the core Storybook version (8.6.14).

---

## 2. Storybook Configuration

### `.storybook/main.ts`

**CRITICAL:** The Tailwind config must be **inlined** in the Vite config, not imported from a separate file. This ensures PostCSS processes the config correctly.

```typescript
import type { StorybookConfig } from "@storybook/react-vite";
import path from "path";
import svgr from "vite-plugin-svgr";

const config: StorybookConfig = {
  stories: [
    "../ui/**/*.stories.@(js|jsx|mjs|ts|tsx)",
  ],
  addons: [
    "@storybook/addon-links",
    "@storybook/addon-essentials",
    "@storybook/addon-interactions",
    "@storybook/addon-themes",
  ],
  framework: {
    name: "@storybook/react-vite",
    options: {},
  },
  viteFinal: async (config) => {
    // 1. Add SVGR plugin for SVG imports
    config.plugins = config.plugins || [];
    config.plugins.push(svgr());

    // 2. Add path aliases
    if (config.resolve) {
      config.resolve.alias = {
        ...config.resolve.alias,
        "@": path.resolve(__dirname, "../client/src"),
        "ui": path.resolve(__dirname, "../ui"),
        "util": path.resolve(__dirname, "../util"),
        "shared": path.resolve(__dirname, "../shared"),
      };
    }

    // 3. CRITICAL: Inline Tailwind config with PostCSS processing
    config.css = {
      ...config.css,
      postcss: {
        plugins: [
          require('tailwindcss')({
            // Content paths - scan all workspace folders
            content: [
              path.resolve(__dirname, "../ui/**/*.{js,ts,jsx,tsx}"),
              path.resolve(__dirname, "../.storybook/**/*.{js,ts,jsx,tsx}"),
              path.resolve(__dirname, "../client/src/**/*.{js,ts,jsx,tsx}"),
            ],
            // Dark mode with class strategy
            darkMode: ["class"],
            // Theme configuration
            theme: {
              container: {
                center: true,
                padding: "2rem",
                screens: {
                  "2xl": "1400px",
                },
              },
              extend: {
                fontFamily: {
                  sans: ['Open Sans', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'sans-serif'],
                },
                // shadcn/ui colors using HSL format
                colors: {
                  border: "hsl(var(--border))",
                  input: "hsl(var(--input))",
                  ring: "hsl(var(--ring))",
                  background: "hsl(var(--background))",
                  foreground: "hsl(var(--foreground))",
                  primary: {
                    DEFAULT: "hsl(var(--primary))",
                    foreground: "hsl(var(--primary-foreground))",
                  },
                  secondary: {
                    DEFAULT: "hsl(var(--secondary))",
                    foreground: "hsl(var(--secondary-foreground))",
                  },
                  destructive: {
                    DEFAULT: "hsl(var(--destructive))",
                    foreground: "hsl(var(--destructive-foreground))",
                  },
                  muted: {
                    DEFAULT: "hsl(var(--muted))",
                    foreground: "hsl(var(--muted-foreground))",
                  },
                  accent: {
                    DEFAULT: "hsl(var(--accent))",
                    foreground: "hsl(var(--accent-foreground))",
                  },
                  popover: {
                    DEFAULT: "hsl(var(--popover))",
                    foreground: "hsl(var(--popover-foreground))",
                  },
                  card: {
                    DEFAULT: "hsl(var(--card))",
                    foreground: "hsl(var(--card-foreground))",
                  },
                },
                // Border radius using CSS variable
                borderRadius: {
                  lg: "var(--radius)",
                  md: "calc(var(--radius) - 2px)",
                  sm: "calc(var(--radius) - 4px)",
                },
                // Animations for shadcn components
                keyframes: {
                  "accordion-down": {
                    from: { height: "0" },
                    to: { height: "var(--radix-accordion-content-height)" },
                  },
                  "accordion-up": {
                    from: { height: "var(--radix-accordion-content-height)" },
                    to: { height: "0" },
                  },
                },
                animation: {
                  "accordion-down": "accordion-down 0.2s ease-out",
                  "accordion-up": "accordion-up 0.2s ease-out",
                },
              },
            },
            plugins: [require("tailwindcss-animate")],
          }),
          require('autoprefixer'),
        ],
      },
    };

    return config;
  },
};

export default config;
```

### `.storybook/preview.ts`

```typescript
import type { Preview } from "@storybook/react";
import { withThemeByClassName } from "@storybook/addon-themes";
import "../client/src/styles/globals.css";

const preview: Preview = {
  parameters: {
    controls: {
      matchers: {
        color: /(background|color)$/i,
        date: /Date$/i,
      },
    },
    backgrounds: {
      default: "dark",
      values: [
        {
          name: "dark",
          value: "#0D101A",
        },
        {
          name: "light",
          value: "#ffffff",
        },
      ],
    },
  },
  decorators: [
    withThemeByClassName({
      themes: {
        light: "light",
        dark: "dark",
      },
      defaultTheme: "dark",
    }),
  ],
};

export default preview;
```

---

## 3. Global Styles

### `client/src/styles/globals.css`

**CRITICAL:** CSS variables must use **HSL format** (not hex) to work with Tailwind's `hsl(var(--variable))` pattern.

```css
@import url('https://fonts.googleapis.com/css2?family=Open+Sans:wght@300;400;500;600;700;800&display=swap');
@import './colors.scss';

@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    --radius: 0.5rem;
    /* Using our custom color scale in HSL format */
    --background: 0 0% 100%; /* text-100 #FFFFFF */
    --foreground: 0 0% 10%; /* text-900 #1A1A1A */
    --card: 0 0% 100%;
    --card-foreground: 0 0% 10%;
    --popover: 0 0% 100%;
    --popover-foreground: 0 0% 10%;
    --primary: 253 100% 64%; /* primary-400 #6C47FF */
    --primary-foreground: 0 0% 100%;
    --secondary: 199 100% 48%; /* secondary-500 #03A9F4 */
    --secondary-foreground: 0 0% 100%;
    --muted: 0 0% 91%; /* text-200 #E8E8E8 */
    --muted-foreground: 0 0% 46%; /* text-700 #757575 */
    --accent: 0 0% 91%;
    --accent-foreground: 0 0% 10%;
    --destructive: 4 90% 58%; /* destructive-500 #F44336 */
    --destructive-foreground: 0 0% 100%;
    --border: 0 0% 82%; /* text-300 #D1D1D1 */
    --input: 0 0% 82%;
    --ring: 253 100% 64%; /* primary-400 #6C47FF */
  }

  .dark {
    --background: 222 33% 8%; /* App background #0D101A */
    --foreground: 0 0% 100%; /* text-100 #FFFFFF */
    --card: 0 0% 10%; /* text-900 #1A1A1A */
    --card-foreground: 0 0% 100%;
    --popover: 0 0% 10%;
    --popover-foreground: 0 0% 100%;
    --primary: 253 100% 64%; /* primary-400 #6C47FF */
    --primary-foreground: 0 0% 100%;
    --secondary: 199 100% 48%; /* secondary-500 #03A9F4 */
    --secondary-foreground: 0 0% 100%;
    --muted: 0 0% 37%; /* text-800 #5E5E5E */
    --muted-foreground: 0 0% 64%; /* text-500 #A3A3A3 */
    --accent: 0 0% 37%;
    --accent-foreground: 0 0% 100%;
    --destructive: 4 90% 58%; /* destructive-500 #F44336 */
    --destructive-foreground: 0 0% 100%;
    --border: 0 0% 37%; /* text-800 #5E5E5E */
    --input: 0 0% 37%;
    --ring: 253 100% 64%; /* primary-400 #6C47FF */
  }
}

@layer base {
  * {
    @apply border-border;
  }
  body {
    @apply bg-background text-foreground;
    font-family: 'Open Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  }
}
```

### Converting Hex to HSL

If you have hex colors, convert them to HSL format:

```javascript
// Example conversion
#6C47FF → 253 100% 64%
#03A9F4 → 199 100% 48%
#0D101A → 222 33% 8%
```

**Use online tools:**
- https://www.cssportal.com/css-hex-to-hsl-converter/
- Chrome DevTools color picker (shows HSL)

---

## 4. Package.json Scripts

### Root `package.json`

```json
{
  "name": "makeready",
  "version": "1.0.0",
  "private": true,
  "workspaces": [
    "client",
    "server"
  ],
  "scripts": {
    "dev": "concurrently \"npm run dev:client\" \"npm run dev:server\"",
    "dev:client": "npm run dev --workspace=client",
    "dev:server": "npm run dev --workspace=server",
    "storybook": "storybook dev -p 6006",
    "build-storybook": "storybook build",
    "build": "npm run build --workspaces",
    "build:client": "npm run build --workspace=client",
    "build:server": "npm run build --workspace=server",
    "test": "npm run test --workspaces",
    "lint": "npm run lint --workspaces",
    "clean": "rm -rf node_modules client/node_modules server/node_modules client/dist server/dist"
  },
  "devDependencies": {
    "concurrently": "^8.2.2",
    "typescript": "^5.6.3",
    "vite-plugin-svgr": "^4.5.0"
  }
}
```

---

## 5. Common Issues & Solutions

### Issue 1: Tailwind Classes Not Applying in Storybook

**Symptoms:**
- Classes appear in HTML but have no styles
- `text-2xl`, `font-semibold` don't work

**Solution:**
- ✅ Ensure Tailwind config is **inlined** in `.storybook/main.ts`
- ✅ Check `content` paths include all workspace folders
- ✅ Import `globals.css` in `.storybook/preview.ts`
- ✅ Restart Storybook after config changes

### Issue 2: Dark Mode Text Unreadable

**Symptoms:**
- Text is dark on dark background
- Can't read content in dark mode

**Solution:**
- ✅ Convert CSS variables from hex to HSL format
- ✅ Ensure `.dark` class variables are set correctly
- ✅ Use `hsl(var(--foreground))` pattern in Tailwind config

### Issue 3: SVG Imports Fail

**Symptoms:**
- `Failed to resolve import "*.svg"`
- Logo/icons won't load

**Solution:**
- ✅ Install `vite-plugin-svgr`
- ✅ Add `svgr()` to Vite plugins in `.storybook/main.ts`
- ✅ Import SVGs as: `import Logo from './logo.svg'`

### Issue 4: CSS Variables Not Working

**Symptoms:**
- `var(--primary)` doesn't apply color
- Tailwind colors broken

**Solution:**
- ✅ Use HSL format: `--primary: 253 100% 64%` (not `#6C47FF`)
- ✅ Reference in Tailwind as: `hsl(var(--primary))`
- ✅ Don't include `hsl()` in the variable value itself

### Issue 5: Storybook Won't Build

**Symptoms:**
- `Error: Cannot find module 'tailwindcss'`
- PostCSS errors

**Solution:**
- ✅ Install `tailwindcss`, `postcss`, `autoprefixer` at root level
- ✅ Don't use `tailwind.config.js` - inline config instead
- ✅ Restart Storybook completely (kill process)

---

## 6. Verification Checklist

After setup, verify everything works:

- [ ] Run `npm run storybook` - launches without errors
- [ ] Tailwind classes apply (`text-2xl`, `font-bold`, etc.)
- [ ] Dark mode toggle works
- [ ] Text is readable in both light and dark modes
- [ ] Custom colors work (`bg-primary`, `text-secondary`)
- [ ] SVG imports work (logo displays)
- [ ] CSS variables work (`hsl(var(--primary))`)
- [ ] Component variants apply correctly

---

## 7. Architecture Integration

### Using with Custom CVA Wrapper

```typescript
// util/cva.ts
import { cva as baseCva, type VariantProps } from "class-variance-authority";
import { twMerge } from "tailwind-merge";

export const cva = (base: string, config: any) => {
  const variants = baseCva(base, config);
  return {
    variants: (props: any) => twMerge(variants(props)),
    defaults: config.defaultVariants,
  };
};

export type { VariantProps };
```

### Component Pattern

```typescript
import { observer } from "mobx-react";
import React from "react";
import { cva, VariantProps } from "util/cva";
import { classnames } from "util/classnames";
import "./button.scss";

export const ButtonCva = cva("Button", {
  variants: {
    variant: {
      Default: "bg-primary text-primary-foreground",
      Secondary: "bg-secondary text-secondary-foreground",
    },
  },
  defaultVariants: { variant: "Default" },
});

export interface IButton extends VariantProps<typeof ButtonCva.variants> {
  children?: React.ReactNode;
  className?: string;
}

export const Button = observer(
  React.forwardRef<HTMLButtonElement, IButton>((props, ref) => {
    const {
      children,
      className,
      variant = ButtonCva.defaults?.variant,
    } = props;

    return (
      <button
        ref={ref}
        className={classnames(ButtonCva.variants({ variant }), className)}
      >
        {children}
      </button>
    );
  })
);
```

---

## 8. Next Steps

Once setup is complete:

1. **Create components** using `/component` slash command
2. **Verify in Storybook** that styles apply correctly
3. **Test dark mode** with theme toggle
4. **Add custom colors** by extending CSS variables
5. **Build design system** with consistent color palette

---

## Resources

- [Tailwind CSS Docs](https://tailwindcss.com/docs)
- [shadcn/ui Components](https://ui.shadcn.com/)
- [Storybook Vite Docs](https://storybook.js.org/docs/react/builders/vite)
- [Class Variance Authority](https://cva.style/docs)

---

**Last Updated:** Oct 25, 2025 - Verified working configuration
