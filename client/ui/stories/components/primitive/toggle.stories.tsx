import type { Meta, StoryObj } from '@storybook/react';
import { useState } from 'react';
import { Toggle, ToggleCva } from '../../../components/primitive/toggle/toggle';

const meta = {
  title: 'Primitive/Toggle',
  component: Toggle,
  parameters: {
    layout: 'centered',
    backgrounds: {
      default: 'dark',
      values: [
        { name: 'dark', value: '#0d101a' },
        { name: 'light', value: '#ffffff' },
      ],
    },
  },
  tags: ['autodocs'],
  argTypes: {
    type: {
      control: 'select',
      options: Object.keys(ToggleCva.type),
      description: 'Toggle type (Default switch or Radio)',
    },
  },
} satisfies Meta<typeof Toggle>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {
  args: {
    type: ToggleCva.type.Default,
  },
  render: (args) => {
    const [enabled, setEnabled] = useState(true);
    return (
      <Toggle
        {...args}
        enabled={enabled ? ToggleCva.enabled.True : ToggleCva.enabled.False}
        onChange={setEnabled}
      />
    );
  },
};

export const Disabled: Story = {
  args: {
    type: ToggleCva.type.Default,
    enabled: ToggleCva.enabled.True,
    disabled: true,
  },
};

export const Radio: Story = {
  args: {
    type: ToggleCva.type.Radio,
  },
  render: (args) => {
    const [enabled, setEnabled] = useState(true);
    return (
      <Toggle
        {...args}
        enabled={enabled ? ToggleCva.enabled.True : ToggleCva.enabled.False}
        onChange={setEnabled}
      />
    );
  },
};

export const RadioDisabled: Story = {
  args: {
    type: ToggleCva.type.Radio,
    enabled: ToggleCva.enabled.True,
    disabled: true,
  },
};
