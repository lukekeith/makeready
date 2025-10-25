import type { Meta, StoryObj } from '@storybook/react'
import { Button, ButtonCva } from '../../../components/primitive/button/button'
import { SocialButton } from '../../../components/primitive/social-button/social-button'
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
    <div className="flex flex-col gap-6">
      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <div className="flex flex-col gap-2">
          <label htmlFor="email" className="text-sm font-medium text-text-100">
            Email
          </label>
          <input
            id="email"
            type="email"
            placeholder="name@example.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            disabled={isLoading}
            className="flex h-10 w-full rounded-md border border-text-700 bg-transparent px-3 py-2 text-sm text-text-100 placeholder:text-text-600 focus:outline-none focus:ring-2 focus:ring-primary-400 focus:border-transparent disabled:cursor-not-allowed disabled:opacity-50"
            required
          />
        </div>
        <Button
          type="submit"
          variant={ButtonCva.variant.Default}
          disabled={isLoading}
        >
          {isLoading ? 'Signing in...' : 'Sign In with Email'}
        </Button>
      </form>

      <div className="relative">
        <div className="absolute inset-0 flex items-center">
          <span className="w-full border-t border-text-700"></span>
        </div>
        <div className="relative flex justify-center text-xs uppercase">
          <span className="bg-background px-2 text-text-600">Or continue with</span>
        </div>
      </div>

      <div className="flex flex-col gap-3">
        <SocialButton provider="google" disabled={isLoading} />
        <SocialButton provider="github" disabled={isLoading} />
        <SocialButton provider="facebook" disabled={isLoading} />
      </div>
    </div>
  )
}

export const CenteredCard: Story = {
  render: () => (
    <div className="min-h-screen flex items-center justify-center bg-background p-4">
      <div className="w-full max-w-sm">
        <div className="flex flex-col gap-6">
          <div className="flex flex-col gap-2 text-center">
            <h1 className="text-2xl font-semibold tracking-tight text-text-100">
              Create an account
            </h1>
            <p className="text-sm text-text-500">
              Enter your email below to create your account
            </p>
          </div>

          <LoginForm />

          <p className="px-8 text-center text-xs text-text-600">
            By clicking continue, you agree to our{' '}
            <a href="#" className="underline underline-offset-4 hover:text-text-400">
              Terms of Service
            </a>{' '}
            and{' '}
            <a href="#" className="underline underline-offset-4 hover:text-text-400">
              Privacy Policy
            </a>
            .
          </p>
        </div>
      </div>
    </div>
  ),
}

export const SplitLayout: Story = {
  render: () => (
    <div className="min-h-screen grid lg:grid-cols-2">
      {/* Left Panel - Brand/Testimonial */}
      <div className="hidden lg:flex lg:flex-col lg:justify-between bg-text-900 p-10 text-text-100">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 bg-primary-400 rounded-lg"></div>
          <span className="text-lg font-semibold">MakeReady</span>
        </div>

        <div className="space-y-4">
          <blockquote className="text-lg font-medium">
            "This library has saved me countless hours of work and helped me deliver
            stunning designs to my clients faster than ever before."
          </blockquote>
          <div className="text-sm text-text-400">
            Sofia Davis
          </div>
        </div>
      </div>

      {/* Right Panel - Login Form */}
      <div className="flex items-center justify-center p-8">
        <div className="w-full max-w-sm">
          <div className="flex flex-col gap-6">
            <div className="flex flex-col gap-2">
              <h1 className="text-2xl font-semibold tracking-tight text-text-100">
                Create an account
              </h1>
              <p className="text-sm text-text-500">
                Enter your email below to create your account
              </p>
            </div>

            <LoginForm />

            <p className="px-8 text-center text-xs text-text-600">
              By clicking continue, you agree to our{' '}
              <a href="#" className="underline underline-offset-4 hover:text-text-400">
                Terms of Service
              </a>{' '}
              and{' '}
              <a href="#" className="underline underline-offset-4 hover:text-text-400">
                Privacy Policy
              </a>
              .
            </p>
          </div>
        </div>
      </div>
    </div>
  ),
}

export const MinimalCenter: Story = {
  render: () => (
    <div className="min-h-screen flex items-center justify-center bg-background p-4">
      <div className="w-full max-w-sm">
        <div className="flex flex-col gap-6">
          <div className="flex flex-col gap-2 text-center">
            <h1 className="text-3xl font-bold text-text-100">
              Welcome back
            </h1>
            <p className="text-sm text-text-500">
              Sign in to your account to continue
            </p>
          </div>

          <LoginForm />
        </div>
      </div>
    </div>
  ),
}
