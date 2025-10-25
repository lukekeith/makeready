# MakeReady Design System

## Typography

### Font Family

The web app uses **Open Sans** as the primary font family.

```css
font-family: 'Open Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
```

**Weights Available:**
- 300 - Light
- 400 - Regular (default)
- 500 - Medium
- 600 - Semibold
- 700 - Bold
- 800 - Extrabold

### Usage in Tailwind

```tsx
<h1 className="font-light">Light heading</h1>
<p className="font-normal">Regular text</p>
<button className="font-medium">Medium button</button>
<h2 className="font-semibold">Semibold heading</h2>
<h1 className="font-bold">Bold heading</h1>
<h1 className="font-extrabold">Extrabold heading</h1>
```

### Usage in CSS

```css
.my-class {
  font-family: theme('fontFamily.sans');
  font-weight: 600; /* Semibold */
}
```

## Colors

### Brand Color

**Primary Purple:** `#6C47FF` (from your logo)

Used for:
- Primary buttons
- Links
- Focus rings
- Interactive elements

### Color System

The design system uses HSL color values for better dark mode support:

**Light Mode:**
```css
--primary: 263 85% 65%;
--background: 0 0% 100%;
--foreground: 240 10% 3.9%;
```

**Dark Mode (Default):**
```css
--primary: 263 85% 65%;
--background: 240 10% 3.9%;
--foreground: 0 0% 98%;
```

### Using Colors in Tailwind

```tsx
<button className="bg-primary text-primary-foreground">Primary</button>
<div className="bg-secondary text-secondary-foreground">Secondary</div>
<div className="bg-muted text-muted-foreground">Muted</div>
<div className="border-border">Bordered</div>
```

## Components

### Social Sign-In Buttons

Dimensions match Google's standard:
- **Height:** 48px (h-12)
- **Padding:** 24px horizontal (px-6)
- **Font Size:** 16px (text-base)
- **Font Weight:** 500 (font-medium)

```tsx
import { SocialButton } from '@/components/ui/social-button'

<SocialButton provider="google" />
// Renders: "Sign up with Google" with icon
```

**Custom Label:**
```tsx
<SocialButton provider="google" label="Sign in with Google" />
```

**Full Width:**
```tsx
<SocialButton provider="google" className="w-full" />
```

### Button Variants

All shadcn/ui button variants are available:

```tsx
<Button variant="default">Default</Button>
<Button variant="destructive">Destructive</Button>
<Button variant="outline">Outline</Button>
<Button variant="secondary">Secondary</Button>
<Button variant="ghost">Ghost</Button>
<Button variant="link">Link</Button>
```

**Sizes:**
```tsx
<Button size="sm">Small</Button>
<Button size="default">Default</Button>
<Button size="lg">Large</Button>
<Button size="icon">Icon Only</Button>
```

### Icons

**Icon Sizes:**
```tsx
<Icon size="xs">...</Icon>   // 12px
<Icon size="sm">...</Icon>   // 16px
<Icon size="md">...</Icon>   // 20px (default)
<Icon size="lg">...</Icon>   // 24px
<Icon size="xl">...</Icon>   // 32px
<Icon size="2xl">...</Icon>  // 40px
```

**Social Icons:**
- Google: `FaGoogle`
- Facebook: `FaFacebook`
- Apple: `FaApple`
- X/Twitter: `FaXTwitter`
- GitHub: `FaGithub`
- LinkedIn: `FaLinkedin`
- Instagram: `FaInstagram`
- YouTube: `FaYoutube`
- Discord: `FaDiscord`
- Slack: `FaSlack`
- TikTok: `FaTiktok`
- Spotify: `FaSpotify`

See [ICONS.md](./ICONS.md) for complete icon documentation.

## Spacing

Standard Tailwind spacing scale:
- `gap-2` = 8px
- `gap-3` = 12px
- `gap-4` = 16px
- `gap-6` = 24px
- `gap-8` = 32px

**Example Auth Layout:**
```tsx
<div className="flex flex-col gap-3 w-96">
  <SocialButton provider="google" className="w-full" />
  <SocialButton provider="facebook" className="w-full" />
  <SocialButton provider="apple" className="w-full" />
</div>
```

## Border Radius

Controlled by CSS variable `--radius`:

```css
--radius: 0.5rem; /* 8px */
```

**Usage:**
```tsx
<div className="rounded-lg">Large</div>   // var(--radius)
<div className="rounded-md">Medium</div>  // calc(var(--radius) - 2px)
<div className="rounded-sm">Small</div>   // calc(var(--radius) - 4px)
```

## Dark Mode (Default)

The app defaults to dark mode. The HTML has `class="dark"` by default.

**Toggle Dark Mode:**
```tsx
// Remove dark class
document.documentElement.classList.remove('dark')

// Add dark class
document.documentElement.classList.add('dark')

// Toggle
document.documentElement.classList.toggle('dark')
```

**React Hook:**
```tsx
import { useState, useEffect } from 'react'

function useDarkMode() {
  const [isDark, setIsDark] = useState(true)

  useEffect(() => {
    if (isDark) {
      document.documentElement.classList.add('dark')
    } else {
      document.documentElement.classList.remove('dark')
    }
  }, [isDark])

  return [isDark, setIsDark] as const
}
```

## Accessibility

### Font Size

All components use relative font sizes (rem) for accessibility.

### Color Contrast

All color combinations meet WCAG AA standards for contrast.

### Focus States

All interactive elements have visible focus rings using the primary color:

```css
focus-visible:ring-1 focus-visible:ring-ring
```

### Icon-Only Buttons

Always include `aria-label`:

```tsx
<button aria-label="Close menu">
  <Icon><X /></Icon>
</button>
```

## Responsive Design

Tailwind responsive breakpoints:

```tsx
<div className="text-sm md:text-base lg:text-lg">
  Responsive text size
</div>

<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3">
  Responsive grid
</div>
```

## Component Patterns

### Auth Form

```tsx
<div className="flex flex-col gap-4 w-96 p-8 rounded-lg border bg-card">
  <div className="flex flex-col gap-2 text-center mb-4">
    <h2 className="text-2xl font-bold">Welcome Back</h2>
    <p className="text-sm text-muted-foreground">
      Choose a provider to sign in
    </p>
  </div>

  <SocialButton provider="google" className="w-full" />
  <SocialButton provider="facebook" className="w-full" />
  <SocialButton provider="apple" className="w-full" />

  <div className="relative my-4">
    <div className="absolute inset-0 flex items-center">
      <span className="w-full border-t" />
    </div>
    <div className="relative flex justify-center text-xs uppercase">
      <span className="bg-card px-2 text-muted-foreground">
        Or continue with email
      </span>
    </div>
  </div>
</div>
```

### Card Pattern

```tsx
<div className="rounded-lg border bg-card p-6">
  <h3 className="text-lg font-semibold mb-2">Card Title</h3>
  <p className="text-sm text-muted-foreground">Card content</p>
</div>
```

### Status Message

```tsx
<div className="flex items-center gap-2 p-4 rounded-lg bg-muted">
  <Icon size="lg" className="text-green-500">
    <CheckCircle />
  </Icon>
  <span>Success message</span>
</div>
```

## Storybook

All components are documented in Storybook with live examples:

```bash
npm run storybook
```

Browse to http://localhost:6006 to see:
- All component variants
- Interactive controls
- Dark/light mode toggle
- Usage examples

## Future: Platform-Specific Fonts

Each platform will have its own typography:

- **Web:** Open Sans (current)
- **iOS:** San Francisco (native)
- **Android:** Roboto (native)

This ensures each platform feels native while maintaining brand consistency through color and component design.
