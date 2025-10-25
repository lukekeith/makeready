# Icon Library Guide

MakeReady includes two comprehensive icon libraries:

## 1. Lucide React (General UI Icons)

Lucide provides beautiful, consistent icons for general UI purposes.

### Usage

```tsx
import { Home, Settings, User, Bell } from 'lucide-react'
import { Icon } from '@/components/ui/icon'

function MyComponent() {
  return (
    <Icon size="lg">
      <Home />
    </Icon>
  )
}
```

### Popular Icons

**Navigation:**
- `Home`, `Settings`, `User`, `Users`, `Bell`, `Search`, `Menu`

**Actions:**
- `Plus`, `Minus`, `Edit`, `Trash2`, `Download`, `Upload`, `Share2`, `Send`, `Check`, `X`

**Status:**
- `AlertCircle`, `Info`, `HelpCircle`, `CheckCircle`, `XCircle`

**Communication:**
- `Mail`, `Phone`, `MessageSquare`, `Calendar`, `Clock`

**Media:**
- `Image`, `File`, `Folder`, `Video`, `Music`

**Auth:**
- `Lock`, `Unlock`, `Eye`, `EyeOff`, `LogIn`, `LogOut`, `UserPlus`

**Other:**
- `Heart`, `Star`, `Filter`, `SortAsc`, `MoreHorizontal`, `MoreVertical`
- `ChevronDown`, `ChevronUp`, `ChevronLeft`, `ChevronRight`

[Browse all Lucide icons →](https://lucide.dev/icons/)

## 2. React Icons (Social Media Icons)

React Icons provides comprehensive icon sets including all major social media platforms.

### Usage

```tsx
import { FaGoogle, FaFacebook, FaApple } from 'react-icons/fa'
import { FaXTwitter } from 'react-icons/fa6'
import { Icon } from '@/components/ui/icon'

function MyComponent() {
  return (
    <Icon size="xl">
      <FaGoogle />
    </Icon>
  )
}
```

### Social Media Icons

From `react-icons/fa`:
- `FaGoogle` - Google
- `FaFacebook` - Facebook
- `FaApple` - Apple
- `FaTwitter` - Twitter (old logo)
- `FaGithub` - GitHub
- `FaLinkedin` - LinkedIn
- `FaInstagram` - Instagram
- `FaYoutube` - YouTube
- `FaDiscord` - Discord
- `FaSlack` - Slack
- `FaTiktok` - TikTok
- `FaSpotify` - Spotify

From `react-icons/fa6`:
- `FaXTwitter` - X (new Twitter logo)

[Browse all React Icons →](https://react-icons.github.io/react-icons/)

## Icon Component

The `Icon` wrapper provides consistent sizing:

```tsx
import { Icon } from '@/components/ui/icon'

<Icon size="xs">...</Icon>   // 12px (w-3 h-3)
<Icon size="sm">...</Icon>   // 16px (w-4 h-4)
<Icon size="md">...</Icon>   // 20px (w-5 h-5) - default
<Icon size="lg">...</Icon>   // 24px (w-6 h-6)
<Icon size="xl">...</Icon>   // 32px (w-8 h-8)
<Icon size="2xl">...</Icon>  // 40px (w-10 h-10)
```

### Styling Icons

Apply Tailwind classes directly to the Icon component:

```tsx
<Icon size="lg" className="text-primary">
  <Heart />
</Icon>

<Icon size="xl" className="text-red-500">
  <AlertCircle />
</Icon>

<Icon size="md" className="text-muted-foreground hover:text-foreground transition-colors">
  <Settings />
</Icon>
```

## Social Sign-In Buttons

Use the pre-built `SocialButton` component for authentication:

```tsx
import { SocialButton } from '@/components/ui/social-button'

function SignIn() {
  return (
    <div className="flex flex-col gap-3">
      <SocialButton provider="google" />
      <SocialButton provider="facebook" />
      <SocialButton provider="apple" />
      <SocialButton provider="twitter" />
      <SocialButton provider="github" />
    </div>
  )
}
```

### Custom Labels

```tsx
<SocialButton
  provider="google"
  label="Sign in with Google"
/>

<SocialButton
  provider="github"
  label="Connect GitHub Account"
/>
```

### Button Variants

```tsx
<SocialButton provider="google" variant="default" />
<SocialButton provider="apple" variant="outline" />
<SocialButton provider="github" variant="secondary" />
```

## Examples

### Navigation Bar

```tsx
import { Home, Search, User, Bell } from 'lucide-react'
import { Icon } from '@/components/ui/icon'

function NavBar() {
  return (
    <nav className="flex gap-4">
      <button>
        <Icon size="lg"><Home /></Icon>
      </button>
      <button>
        <Icon size="lg"><Search /></Icon>
      </button>
      <button>
        <Icon size="lg"><Bell /></Icon>
      </button>
      <button>
        <Icon size="lg"><User /></Icon>
      </button>
    </nav>
  )
}
```

### Button with Icon

```tsx
import { Download } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Icon } from '@/components/ui/icon'

function DownloadButton() {
  return (
    <Button>
      <Icon size="sm">
        <Download />
      </Icon>
      Download Report
    </Button>
  )
}
```

### Status Indicator

```tsx
import { CheckCircle, AlertCircle, XCircle } from 'lucide-react'
import { Icon } from '@/components/ui/icon'

function StatusMessage({ status }: { status: 'success' | 'warning' | 'error' }) {
  const icons = {
    success: <CheckCircle className="text-green-500" />,
    warning: <AlertCircle className="text-yellow-500" />,
    error: <XCircle className="text-red-500" />,
  }

  return (
    <div className="flex items-center gap-2">
      <Icon size="lg">{icons[status]}</Icon>
      <span>Status message here</span>
    </div>
  )
}
```

### Social Links Footer

```tsx
import { FaTwitter, FaGithub, FaLinkedin, FaInstagram } from 'react-icons/fa'
import { Icon } from '@/components/ui/icon'

function SocialLinks() {
  return (
    <div className="flex gap-4">
      <a href="https://twitter.com/yourhandle" className="hover:text-primary transition-colors">
        <Icon size="lg"><FaTwitter /></Icon>
      </a>
      <a href="https://github.com/yourhandle" className="hover:text-primary transition-colors">
        <Icon size="lg"><FaGithub /></Icon>
      </a>
      <a href="https://linkedin.com/in/yourhandle" className="hover:text-primary transition-colors">
        <Icon size="lg"><FaLinkedin /></Icon>
      </a>
      <a href="https://instagram.com/yourhandle" className="hover:text-primary transition-colors">
        <Icon size="lg"><FaInstagram /></Icon>
      </a>
    </div>
  )
}
```

## Storybook

View all available icons in Storybook:

```bash
npm run storybook
```

Navigate to:
- **UI/Icons** - Browse all general UI and social icons
- **UI/SocialButton** - See social sign-in buttons in action

## Tips

1. **Consistent Sizing** - Always wrap icons in the `Icon` component for consistent sizing
2. **Semantic Colors** - Use Tailwind semantic color classes like `text-primary`, `text-destructive`
3. **Accessibility** - Add `aria-label` to icon-only buttons
4. **Performance** - Icons are tree-shaken, only imported icons are included in your bundle

```tsx
// Good - tree-shaken
import { Home, User } from 'lucide-react'

// Bad - imports everything
import * as Icons from 'lucide-react'
```
