import type { Meta, StoryObj } from '@storybook/react'
import { Button, ButtonCva } from '../../../components/primitive/button/button'

const meta = {
  title: 'Primitive/Button',
  component: Button,
  parameters: {
    layout: 'centered',
  },
  tags: ['autodocs'],
  argTypes: {
    variant: {
      control: 'select',
      options: Object.keys(ButtonCva.variant),
    },
    size: {
      control: 'select',
      options: Object.keys(ButtonCva.size),
    },
  },
} satisfies Meta<typeof Button>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  args: {
    children: 'Button',
    variant: ButtonCva.variant.Default,
  },
}

export const Destructive: Story = {
  args: {
    children: 'Delete',
    variant: ButtonCva.variant.Destructive,
  },
}

export const Outline: Story = {
  args: {
    children: 'Outline',
    variant: ButtonCva.variant.Outline,
  },
}

export const Secondary: Story = {
  args: {
    children: 'Secondary',
    variant: ButtonCva.variant.Secondary,
  },
}

export const Ghost: Story = {
  args: {
    children: 'Ghost',
    variant: ButtonCva.variant.Ghost,
  },
}

export const Link: Story = {
  args: {
    children: 'Link',
    variant: ButtonCva.variant.Link,
  },
}

export const Small: Story = {
  args: {
    children: 'Small',
    size: ButtonCva.size.Sm,
  },
}

export const Large: Story = {
  args: {
    children: 'Large',
    size: ButtonCva.size.Lg,
  },
}

export const AllVariants: Story = {
  render: () => (
    <div className="flex flex-col gap-4">
      <div className="flex gap-2">
        <Button variant={ButtonCva.variant.Default}>Default</Button>
        <Button variant={ButtonCva.variant.Destructive}>Destructive</Button>
        <Button variant={ButtonCva.variant.Outline}>Outline</Button>
        <Button variant={ButtonCva.variant.Secondary}>Secondary</Button>
        <Button variant={ButtonCva.variant.Ghost}>Ghost</Button>
        <Button variant={ButtonCva.variant.Link}>Link</Button>
      </div>
      <div className="flex gap-2 items-center">
        <Button size={ButtonCva.size.Sm}>Small</Button>
        <Button size={ButtonCva.size.Default}>Default</Button>
        <Button size={ButtonCva.size.Lg}>Large</Button>
      </div>
    </div>
  ),
}
