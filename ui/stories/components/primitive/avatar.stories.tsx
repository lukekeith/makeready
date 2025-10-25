import type { Meta, StoryObj } from '@storybook/react'
import { Avatar, AvatarImage, AvatarFallback } from '../../../components/primitive/avatar/avatar'

const meta = {
  title: 'Primitive/Avatar',
  component: Avatar,
  parameters: {
    layout: 'centered',
  },
  tags: ['autodocs'],
} satisfies Meta<typeof Avatar>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: () => (
    <Avatar>
      <AvatarImage src="https://github.com/shadcn.png" alt="@shadcn" />
      <AvatarFallback>CN</AvatarFallback>
    </Avatar>
  ),
}

export const Fallback: Story = {
  render: () => (
    <Avatar>
      <AvatarImage src="https://invalid-url.com/image.png" alt="User" />
      <AvatarFallback>JD</AvatarFallback>
    </Avatar>
  ),
}

export const CustomSize: Story = {
  render: () => (
    <div className="flex items-center gap-4">
      <Avatar style={{ width: '32px', height: '32px' }}>
        <AvatarImage src="https://github.com/shadcn.png" alt="Small" />
        <AvatarFallback className="text-xs">SM</AvatarFallback>
      </Avatar>
      <Avatar>
        <AvatarImage src="https://github.com/shadcn.png" alt="Medium" />
        <AvatarFallback>MD</AvatarFallback>
      </Avatar>
      <Avatar style={{ width: '56px', height: '56px' }}>
        <AvatarImage src="https://github.com/shadcn.png" alt="Large" />
        <AvatarFallback className="text-lg">LG</AvatarFallback>
      </Avatar>
      <Avatar style={{ width: '72px', height: '72px' }}>
        <AvatarImage src="https://github.com/shadcn.png" alt="Extra Large" />
        <AvatarFallback className="text-xl">XL</AvatarFallback>
      </Avatar>
    </div>
  ),
}

export const AvatarGroup: Story = {
  render: () => (
    <div className="flex -space-x-4">
      <Avatar className="border-2 border-background">
        <AvatarImage src="https://github.com/shadcn.png" alt="User 1" />
        <AvatarFallback>U1</AvatarFallback>
      </Avatar>
      <Avatar className="border-2 border-background">
        <AvatarImage src="https://github.com/vercel.png" alt="User 2" />
        <AvatarFallback>U2</AvatarFallback>
      </Avatar>
      <Avatar className="border-2 border-background">
        <AvatarImage src="https://github.com/microsoft.png" alt="User 3" />
        <AvatarFallback>U3</AvatarFallback>
      </Avatar>
      <Avatar className="border-2 border-background">
        <AvatarFallback>U4</AvatarFallback>
      </Avatar>
    </div>
  ),
}

export const WithColoredFallbacks: Story = {
  render: () => (
    <div className="flex items-center gap-4">
      <Avatar>
        <AvatarFallback className="bg-primary-400 text-text-100">AB</AvatarFallback>
      </Avatar>
      <Avatar>
        <AvatarFallback className="bg-secondary-500 text-text-100">CD</AvatarFallback>
      </Avatar>
      <Avatar>
        <AvatarFallback className="bg-destructive-500 text-text-100">EF</AvatarFallback>
      </Avatar>
      <Avatar>
        <AvatarFallback className="bg-text-700 text-text-100">GH</AvatarFallback>
      </Avatar>
    </div>
  ),
}

export const Rounded: Story = {
  render: () => (
    <div className="flex items-center gap-4">
      <Avatar className="rounded-lg">
        <AvatarImage src="https://github.com/shadcn.png" alt="Rounded LG" />
        <AvatarFallback className="rounded-lg">LG</AvatarFallback>
      </Avatar>
      <Avatar className="rounded-md">
        <AvatarImage src="https://github.com/shadcn.png" alt="Rounded MD" />
        <AvatarFallback className="rounded-md">MD</AvatarFallback>
      </Avatar>
      <Avatar className="rounded-sm">
        <AvatarImage src="https://github.com/shadcn.png" alt="Rounded SM" />
        <AvatarFallback className="rounded-sm">SM</AvatarFallback>
      </Avatar>
      <Avatar className="rounded-none">
        <AvatarImage src="https://github.com/shadcn.png" alt="Square" />
        <AvatarFallback className="rounded-none">SQ</AvatarFallback>
      </Avatar>
    </div>
  ),
}
