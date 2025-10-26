import type { Meta, StoryObj } from '@storybook/react'
import { Button } from '../../../components/primitive/button/button'
import { Input } from '../../../components/primitive/input/input'
import { Label } from '../../../components/primitive/label/label'
import { SocialButton } from '../../../components/primitive/social-button/social-button'
import { AuthLayout } from '../../../components/layout/auth/auth'
import { useState } from 'react'

const meta = {
  title: 'Layout/Login',
  parameters: {
    layout: 'fullscreen',
  },
  tags: ['autodocs'],
} satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

// Simple login form component for the story
const LoginForm = () => {
  const [email, setEmail] = useState('')
  const [isLoading, setIsLoading] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsLoading(true)
    // Simulate API call
    setTimeout(() => {
      setIsLoading(false)
    }, 2000)
  }

  return (
    <div className="grid gap-6">
      <form onSubmit={handleSubmit}>
        <div className="grid gap-4">
          <div className="grid gap-2">
            <Label htmlFor="email">Email</Label>
            <Input
              id="email"
              type="email"
              placeholder="name@example.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              disabled={isLoading}
              required
            />
          </div>
          <Button
            type="submit"
            disabled={isLoading}
            className="w-full"
          >
            {isLoading ? 'Signing in...' : 'Sign In with Email'}
          </Button>
        </div>
      </form>

      <div className="relative">
        <div className="absolute inset-0 flex items-center">
          <span className="w-full border-t" />
        </div>
        <div className="relative flex justify-center text-xs uppercase">
          <span className="bg-background px-2 text-muted-foreground">
            Or continue with
          </span>
        </div>
      </div>
    </div>
  )
}

// Social buttons component that can be passed to AuthLayout
const SocialButtons = ({ disabled = false }: { disabled?: boolean }) => (
  <>
    <SocialButton provider="google" disabled={disabled} />
    <SocialButton provider="github" disabled={disabled} />
  </>
)

export const CenteredCard: Story = {
  render: () => (
    <AuthLayout
      layout="Centered"
      title="Create an account"
      description="Enter your email below to create your account"
      emailForm={<LoginForm />}
      socialButtons={<SocialButtons />}
    />
  ),
}

export const SplitLayout: Story = {
  render: () => (
    <AuthLayout
      layout="Split"
      title="Create an account"
      description="Enter your email below to create your account"
      showBranding={true}
      emailForm={<LoginForm />}
      socialButtons={<SocialButtons />}
    />
  ),
}

export const MinimalCenter: Story = {
  render: () => (
    <AuthLayout
      layout="Minimal"
      title="Welcome back"
      description="Sign in to your account to continue"
      showTerms={false}
      emailForm={<LoginForm />}
      socialButtons={<SocialButtons />}
    />
  ),
}

export const SplitLayoutGoogleOnly: Story = {
  render: () => (
    <AuthLayout
      layout="Split"
      title="Welcome to MakeReady"
      description="Sign in with your Google account to continue"
      showBranding={true}
      socialButtons={<SocialButton provider="google" />}
    />
  ),
}
