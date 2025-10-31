import type { Meta, StoryObj } from '@storybook/react';
import { useState } from 'react';
import { VerifyCode, VerifyCodeCva } from '../../../components/primitive/verify-code/verify-code';

const meta = {
  title: 'Primitive/VerifyCode',
  component: VerifyCode,
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
    size: {
      control: 'select',
      options: Object.keys(VerifyCodeCva.size),
      description: 'Size of the verification code inputs',
    },
    length: {
      control: { type: 'number', min: 4, max: 8 },
      description: 'Number of digits in the code',
    },
    disabled: {
      control: 'boolean',
      description: 'Disable the input',
    },
  },
} satisfies Meta<typeof VerifyCode>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {
  args: {
    size: VerifyCodeCva.size.Default,
    length: 6,
    autoFocus: true,
  },
  render: (args) => {
    const [code, setCode] = useState('');
    return (
      <div style={{ width: '400px' }}>
        <VerifyCode
          {...args}
          value={code}
          onChange={setCode}
          onComplete={(completedCode) => {
            console.log('Code completed:', completedCode);
            alert(`Code entered: ${completedCode}`);
          }}
        />
        <p style={{ color: 'white', marginTop: '16px', textAlign: 'center' }}>
          Current code: {code || '(empty)'}
        </p>
      </div>
    );
  },
};

export const Disabled: Story = {
  args: {
    size: VerifyCodeCva.size.Default,
    length: 6,
    value: '123456',
    disabled: true,
  },
  render: (args) => {
    return (
      <div style={{ width: '400px' }}>
        <VerifyCode {...args} />
      </div>
    );
  },
};

export const Large: Story = {
  args: {
    size: VerifyCodeCva.size.Large,
    length: 6,
    autoFocus: true,
  },
  render: (args) => {
    const [code, setCode] = useState('');
    return (
      <div style={{ width: '500px' }}>
        <VerifyCode
          {...args}
          value={code}
          onChange={setCode}
          onComplete={(completedCode) => {
            console.log('Code completed:', completedCode);
          }}
        />
        <p style={{ color: 'white', marginTop: '16px', textAlign: 'center' }}>
          Current code: {code || '(empty)'}
        </p>
      </div>
    );
  },
};

export const FourDigit: Story = {
  args: {
    size: VerifyCodeCva.size.Default,
    length: 4,
    autoFocus: true,
  },
  render: (args) => {
    const [code, setCode] = useState('');
    return (
      <div style={{ width: '300px' }}>
        <VerifyCode
          {...args}
          value={code}
          onChange={setCode}
          onComplete={(completedCode) => {
            console.log('Code completed:', completedCode);
          }}
        />
        <p style={{ color: 'white', marginTop: '16px', textAlign: 'center' }}>
          Current code: {code || '(empty)'}
        </p>
      </div>
    );
  },
};
