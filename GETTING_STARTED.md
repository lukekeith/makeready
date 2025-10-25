# Getting Started with MakeReady

## What's Already Set Up

✅ **Monorepo Structure** - Client and Server workspaces
✅ **React Web App** - Vite + TypeScript + React 18
✅ **shadcn/ui** - Component library with dark mode
✅ **Tailwind CSS** - Configured with your brand color (#6C47FF)
✅ **MobX** - State management with Domain/Session/UI stores
✅ **Storybook** - Component development environment
✅ **Express Server** - Backend API ready to build
✅ **TypeScript** - Full type safety across the stack

## Quick Start

### 1. Start Storybook (Component Development)

```bash
npm run storybook
```

Visit **http://localhost:6006/** to see your UI components.

Currently includes:
- Button component with all variants (default, destructive, outline, secondary, ghost, link)
- Comprehensive icon library (UI icons + Social media icons)
- Social sign-in buttons (Google, Facebook, Apple, Twitter/X, GitHub)
- Dark mode theme with your brand color

### 2. Start the Web Client

```bash
npm run dev:client
```

Visit **http://localhost:5173/** to see your web app.

### 3. Start the API Server

```bash
npm run dev:server
```

API available at **http://localhost:3001/**

Test endpoints:
- `GET /health` - Health check
- `GET /api` - API status

### 4. Start Everything Together

```bash
npm run dev
```

This starts both client and server concurrently.

## Adding Components

### Option 1: Use shadcn/ui CLI

```bash
cd client
npx shadcn@latest add dialog
npx shadcn@latest add dropdown-menu
npx shadcn@latest add form
npx shadcn@latest add input
npx shadcn@latest add label
npx shadcn@latest add select
npx shadcn@latest add tabs
npx shadcn@latest add toast
npx shadcn@latest add tooltip
```

Components are added to `client/src/components/ui/`

### Option 2: Create Custom Components

1. Create component in `client/src/components/ui/mycomponent.tsx`
2. Create story in `client/src/components/ui/mycomponent.stories.tsx`
3. View in Storybook at http://localhost:6006

Example:
```tsx
// client/src/components/ui/card.tsx
export const Card = ({ children }: { children: React.ReactNode }) => {
  return <div className="rounded-lg border bg-card p-6">{children}</div>
}

// client/src/components/ui/card.stories.tsx
import type { Meta, StoryObj } from '@storybook/react'
import { Card } from './card'

const meta = {
  title: 'UI/Card',
  component: Card,
} satisfies Meta<typeof Card>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  args: {
    children: 'Card content',
  },
}
```

## Creating Pages

Pages go in `client/src/pages/`. They can use MobX stores and UI components.

Example:
```tsx
// client/src/pages/Dashboard.tsx
import { observer } from 'mobx-react'
import { Application } from '@/store/ApplicationStore'
import { Button } from '@/components/ui/button'

export const Dashboard = observer(() => {
  const { session } = Application

  return (
    <div className="p-8">
      <h1 className="text-4xl font-bold mb-4">Dashboard</h1>
      {session.isAuthenticated ? (
        <p>Welcome back!</p>
      ) : (
        <Button>Sign In</Button>
      )}
    </div>
  )
})
```

## Using MobX Stores

### Access the Application Store

```tsx
import { Application } from '@/store/ApplicationStore'

// In your component
const { domain, session, ui } = Application
```

### Add a Domain Store

Create `client/src/store/domain/users.domain.ts`:

```tsx
import { observable, makeObservable, action } from 'mobx'
import { Store } from '../Store'
import { ApplicationStore } from '../ApplicationStore'

export class UsersStore extends Store {
  @observable users: User[] = []
  @observable isLoading = false

  constructor(application: ApplicationStore) {
    super(application)
    makeObservable(this)
  }

  @action
  async fetchUsers() {
    this.isLoading = true
    try {
      const response = await fetch('http://localhost:3001/api/users')
      this.users = await response.json()
    } finally {
      this.isLoading = false
    }
  }
}
```

Then add it to `DomainStore.ts`:
```tsx
@observable users = new UsersStore(this.application)
```

## Adding API Endpoints

Create routes in `server/src/routes/`:

```tsx
// server/src/routes/users.ts
import express from 'express'

const router = express.Router()

router.get('/users', (req, res) => {
  res.json([
    { id: 1, name: 'John Doe' },
    { id: 2, name: 'Jane Smith' },
  ])
})

export default router
```

Add to `server/src/index.ts`:
```tsx
import usersRouter from './routes/users'
app.use('/api', usersRouter)
```

## Dark Mode

Dark mode is enabled by default. The app uses your logo color (#6C47FF) as the primary brand color.

To customize colors, edit `client/src/styles/globals.css`:

```css
.dark {
  --primary: 263 85% 65%; /* Your purple color */
  --background: 240 10% 3.9%;
  --foreground: 0 0% 98%;
  /* ... more colors */
}
```

## Project Structure

```
makeready/
├── client/                 # Web application
│   ├── src/
│   │   ├── components/     # UI components
│   │   ├── pages/          # Page components
│   │   ├── store/          # MobX stores
│   │   ├── lib/            # Utilities
│   │   └── styles/         # Global styles
│   ├── .storybook/         # Storybook config
│   └── public/             # Static assets (logo, etc.)
├── server/                 # API server
│   └── src/
│       ├── routes/         # API routes
│       ├── controllers/    # Request handlers
│       └── models/         # Data models
└── shared/                 # Shared types/constants
```

## Next Steps

1. **Browse Storybook** - See all UI components at http://localhost:6006
2. **Add shadcn/ui components** - Use `npx shadcn@latest add <component>`
3. **Create pages** - Build your app in `client/src/pages/`
4. **Add API endpoints** - Create routes in `server/src/routes/`
5. **Add MobX stores** - Manage state in `client/src/store/`

## Tips

- **Always develop components in Storybook first** - This ensures they work in isolation
- **Use MobX stores for state** - Keep components simple and stateless
- **Use shadcn/ui components** - They're already styled for dark mode
- **Test in both light and dark mode** - Storybook has a theme switcher

## Future: iOS App

When ready to add the iOS app:

1. Create `iphone/` directory
2. Set up Swift/SwiftUI project
3. Connect to the same backend API
4. Reuse types from `shared/`

The API is already designed to support multiple clients!

## Support

- Check `README.md` for full documentation
- Browse component examples in Storybook
- Review MobX store patterns in `client/src/store/`

Happy building! 🚀
