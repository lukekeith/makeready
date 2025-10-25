import type { Meta, StoryObj } from '@storybook/react'
import { SocialButton } from '../../../components/primitive/social-button/social-button'
import { ButtonCva } from '../../../components/primitive/button/button'

const meta = {
  title: 'Primitive/SocialButton',
  component: SocialButton,
  parameters: {
    layout: 'centered',
  },
  tags: ['autodocs'],
  argTypes: {
    provider: {
      control: 'select',
      options: ['google', 'facebook', 'apple', 'twitter', 'github'],
    },
    variant: {
      control: 'select',
      options: Object.keys(ButtonCva.variant),
    },
  },
} satisfies Meta<typeof SocialButton>

export default meta
type Story = StoryObj<typeof meta>

export const Google: Story = {
  args: {
    provider: 'google',
  },
}

export const Facebook: Story = {
  args: {
    provider: 'facebook',
  },
}

export const Apple: Story = {
  args: {
    provider: 'apple',
  },
}

export const Twitter: Story = {
  args: {
    provider: 'twitter',
  },
}

export const GitHub: Story = {
  args: {
    provider: 'github',
  },
}

export const CustomLabel: Story = {
  args: {
    provider: 'google',
    label: 'Sign in with Google',
  },
}

export const SignInPage: Story = {
  render: () => (
    <div className="flex flex-col gap-3 w-[600px] max-w-full p-8 rounded-lg border bg-card">
      <div className="flex flex-col gap-2 text-center mb-4">
        <h2 className="text-2xl font-bold">Welcome Back</h2>
        <p className="text-sm text-muted-foreground">
          Choose a provider to sign in
        </p>
      </div>

      <SocialButton provider="google" className="w-full" />
      <SocialButton provider="facebook" className="w-full" />
      <SocialButton provider="apple" className="w-full" />
      <SocialButton provider="twitter" className="w-full" />
      <SocialButton provider="github" className="w-full" />

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

      <button className="text-sm text-primary hover:underline">
        Sign in with email instead
      </button>
    </div>
  ),
}

export const AllProviders: Story = {
  render: () => (
    <div className="flex flex-col gap-4">
      <h2 className="text-2xl font-bold mb-4">All Social Providers</h2>

      <div className="flex flex-col gap-3">
        <SocialButton provider="google" />
        <SocialButton provider="facebook" />
        <SocialButton provider="apple" />
        <SocialButton provider="twitter" />
        <SocialButton provider="github" />
      </div>
    </div>
  ),
}
