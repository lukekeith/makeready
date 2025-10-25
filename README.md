# MakeReady

A full-stack monorepo application built with React, shadcn/ui, MobX, and Express.

## Project Structure

```
makeready/
├── client/              # React web application
│   ├── src/
│   │   ├── components/  # App-specific components
│   │   ├── pages/       # Page components
│   │   ├── store/       # MobX state management
│   │   ├── lib/         # Utilities
│   │   └── styles/      # Global styles
│   ├── .storybook/      # Storybook configuration
│   └── public/          # Static assets
├── server/              # Express API server
│   └── src/
│       ├── routes/      # API routes
│       ├── controllers/ # Request handlers
│       └── models/      # Data models
├── ui/                  # Shared UI components (shadcn/ui)
│   ├── components/      # Reusable components
│   └── stories/         # Storybook stories
├── util/                # Shared utilities
└── shared/              # Shared types and constants
```

## Tech Stack

### Frontend
- **React 18** - UI library
- **TypeScript** - Type safety
- **Vite** - Build tool
- **shadcn/ui** - Component library
- **Tailwind CSS** - Styling
- **Open Sans** - Typography (Google Fonts)
- **MobX** - State management
- **React Router** - Routing
- **Storybook** - Component development
- **Lucide React** - UI icons (1000+)
- **React Icons** - Social media icons

### Backend
- **Express** - Web framework
- **TypeScript** - Type safety
- **Zod** - Validation

## Getting Started

### Prerequisites
- Node.js 18+
- npm

### Installation

```bash
# Install all dependencies
npm install
```

### Development

```bash
# Start both client and server
npm run dev

# Start only the web client
npm run dev:client

# Start only the server
npm run dev:server

# Start Storybook
npm run storybook
```

The web app will be available at `http://localhost:5173`
The API server will be available at `http://localhost:3001`
Storybook will be available at `http://localhost:6006`

### Building

```bash
# Build all apps
npm run build

# Build only client
npm run build:client

# Build only server
npm run build:server
```

## Storybook

All UI components are developed and tested in Storybook. Run `npm run storybook` to:

- View all components in isolation
- Test different component variants
- Interact with components in dark mode
- Verify component behavior before using in pages

### Creating Components with Stories

1. Create your component in `ui/components/`
2. Create a story file in `ui/stories/`
3. Run Storybook to see it in action

Example:
```tsx
// ui/components/my-component.tsx
export const MyComponent = () => { ... }

// ui/stories/my-component.stories.tsx
export const Default: Story = {
  args: { ... }
}
```

## Design System

- **Primary Color**: #6C47FF (from logo)
- **Mode**: Dark mode by default
- **Component Library**: shadcn/ui
- **Styling**: Tailwind CSS with custom theme

## State Management

The app uses MobX with a structured store pattern:

```typescript
ApplicationStore
├── DomainStore    // API data and business logic
├── SessionStore   // User session and auth
└── UIStore        // UI state and transformations
```

### Using Stores

```tsx
import { observer } from 'mobx-react'
import { Application } from '@/store/ApplicationStore'

const MyComponent = observer(() => {
  const { session } = Application
  return <div>{session.isAuthenticated ? 'Logged in' : 'Guest'}</div>
})
```

## API Development

Create new API endpoints in `server/src/routes/`:

```typescript
// server/src/routes/users.ts
import express from 'express'

const router = express.Router()

router.get('/users', (req, res) => {
  res.json({ users: [] })
})

export default router
```

## Adding shadcn/ui Components

To add new shadcn/ui components:

```bash
cd client
npx shadcn@latest add button
npx shadcn@latest add dialog
npx shadcn@latest add form
# etc.
```

All components will be added to `client/src/components/ui/` and automatically configured for dark mode.

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start both client and server |
| `npm run dev:client` | Start web client only |
| `npm run dev:server` | Start API server only |
| `npm run storybook` | Start Storybook |
| `npm run build` | Build all apps |
| `npm test` | Run all tests |
| `npm run clean` | Remove all node_modules and build artifacts |

## Environment Variables

### Client
Create `client/.env`:
```
VITE_API_URL=http://localhost:3001
```

### Server
Create `server/.env`:
```
PORT=3001
NODE_ENV=development
```

## Future: iOS App

The project is structured to support adding a native iOS app later:

```bash
mkdir iphone
cd iphone
# Set up Swift/SwiftUI project
```

The backend API is already set up to support both web and mobile clients.

## Contributing

1. Create a feature branch
2. Make your changes
3. Test in Storybook if UI changes
4. Build and test
5. Submit PR

## License

MIT
