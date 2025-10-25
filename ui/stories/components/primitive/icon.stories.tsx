import type { Meta, StoryObj } from '@storybook/react'
import { Icon, IconCva } from '../../../components/primitive/icon/icon'

// Lucide icons for general UI
import {
  Home,
  Settings,
  User,
  Bell,
  Search,
  Menu,
  X,
  ChevronDown,
  Plus,
  Check,
  AlertCircle,
  Heart,
  Star,
} from 'lucide-react'

// Social icons from react-icons
import {
  FaGoogle,
  FaFacebook,
  FaApple,
  FaTwitter,
  FaGithub,
  FaLinkedin,
  FaInstagram,
  FaYoutube,
  FaDiscord,
  FaSlack,
  FaTiktok,
  FaSpotify,
} from 'react-icons/fa'
import { FaXTwitter } from 'react-icons/fa6'

// Color options for controls
const colorOptions = {
  'primary-100': 'text-primary-100',
  'primary-200': 'text-primary-200',
  'primary-300': 'text-primary-300',
  'primary-400': 'text-primary-400',
  'primary-500': 'text-primary-500',
  'primary-600': 'text-primary-600',
  'primary-700': 'text-primary-700',
  'primary-800': 'text-primary-800',
  'primary-900': 'text-primary-900',
  'secondary-100': 'text-secondary-100',
  'secondary-200': 'text-secondary-200',
  'secondary-300': 'text-secondary-300',
  'secondary-400': 'text-secondary-400',
  'secondary-500': 'text-secondary-500',
  'secondary-600': 'text-secondary-600',
  'secondary-700': 'text-secondary-700',
  'secondary-800': 'text-secondary-800',
  'secondary-900': 'text-secondary-900',
  'text-100': 'text-text-100',
  'text-200': 'text-text-200',
  'text-300': 'text-text-300',
  'text-400': 'text-text-400',
  'text-500': 'text-text-500',
  'text-600': 'text-text-600',
  'text-700': 'text-text-700',
  'text-800': 'text-text-800',
  'text-900': 'text-text-900',
  'destructive-100': 'text-destructive-100',
  'destructive-200': 'text-destructive-200',
  'destructive-300': 'text-destructive-300',
  'destructive-400': 'text-destructive-400',
  'destructive-500': 'text-destructive-500',
  'destructive-600': 'text-destructive-600',
  'destructive-700': 'text-destructive-700',
  'destructive-800': 'text-destructive-800',
  'destructive-900': 'text-destructive-900',
}

const meta = {
  title: 'Primitive/Icon',
  component: Icon,
  parameters: {
    layout: 'centered',
  },
  tags: ['autodocs'],
  argTypes: {
    size: {
      control: 'select',
      options: Object.keys(IconCva.size),
    },
    color: {
      control: 'select',
      options: Object.keys(colorOptions),
      mapping: colorOptions,
    },
  },
} satisfies Meta<typeof Icon>

export default meta
type Story = StoryObj<typeof meta>

export const SocialIcons: Story = {
  render: () => (
    <div className="flex flex-col gap-8 p-8">
      <div>
        <h2 className="text-2xl font-bold mb-4">Social Media Icons</h2>
        <p className="text-muted-foreground mb-6">
          Perfect for sign-in buttons and social links
        </p>

        <div className="grid grid-cols-4 gap-6">
          <div className="flex flex-col items-center gap-2">
            <Icon size={IconCva.size.Xxl} className="text-foreground">
              <FaGoogle />
            </Icon>
            <span className="text-sm text-muted-foreground">Google</span>
          </div>

          <div className="flex flex-col items-center gap-2">
            <Icon size={IconCva.size.Xxl} className="text-blue-600">
              <FaFacebook />
            </Icon>
            <span className="text-sm text-muted-foreground">Facebook</span>
          </div>

          <div className="flex flex-col items-center gap-2">
            <Icon size={IconCva.size.Xxl} className="text-foreground">
              <FaApple />
            </Icon>
            <span className="text-sm text-muted-foreground">Apple</span>
          </div>

          <div className="flex flex-col items-center gap-2">
            <Icon size={IconCva.size.Xxl} className="text-foreground">
              <FaXTwitter />
            </Icon>
            <span className="text-sm text-muted-foreground">X</span>
          </div>

          <div className="flex flex-col items-center gap-2">
            <Icon size={IconCva.size.Xxl} className="text-blue-400">
              <FaTwitter />
            </Icon>
            <span className="text-sm text-muted-foreground">Twitter</span>
          </div>

          <div className="flex flex-col items-center gap-2">
            <Icon size={IconCva.size.Xxl} className="text-foreground">
              <FaGithub />
            </Icon>
            <span className="text-sm text-muted-foreground">GitHub</span>
          </div>

          <div className="flex flex-col items-center gap-2">
            <Icon size={IconCva.size.Xxl} className="text-blue-700">
              <FaLinkedin />
            </Icon>
            <span className="text-sm text-muted-foreground">LinkedIn</span>
          </div>

          <div className="flex flex-col items-center gap-2">
            <Icon size={IconCva.size.Xxl} className="text-pink-600">
              <FaInstagram />
            </Icon>
            <span className="text-sm text-muted-foreground">Instagram</span>
          </div>
        </div>
      </div>
    </div>
  ),
}

export const NavigationIcons: Story = {
  args: {
    color: 'text-100',
  },
  render: (args) => {
    const colorClass = colorOptions[args.color as keyof typeof colorOptions] || 'text-text-100';
    return (
      <div className="flex flex-col gap-8 p-8">
        <div>
          <h2 className="text-2xl font-bold mb-4">Navigation & Menu Icons</h2>
          <div className="grid grid-cols-6 gap-6">
            <div className="flex flex-col items-center gap-2">
              <Icon size={IconCva.size.Xl} className={colorClass}><Home /></Icon>
              <span className="text-xs text-muted-foreground">Home</span>
            </div>
            <div className="flex flex-col items-center gap-2">
              <Icon size={IconCva.size.Xl} className={colorClass}><Settings /></Icon>
              <span className="text-xs text-muted-foreground">Settings</span>
            </div>
            <div className="flex flex-col items-center gap-2">
              <Icon size={IconCva.size.Xl} className={colorClass}><User /></Icon>
              <span className="text-xs text-muted-foreground">User</span>
            </div>
            <div className="flex flex-col items-center gap-2">
              <Icon size={IconCva.size.Xl} className={colorClass}><Bell /></Icon>
              <span className="text-xs text-muted-foreground">Bell</span>
            </div>
            <div className="flex flex-col items-center gap-2">
              <Icon size={IconCva.size.Xl} className={colorClass}><Search /></Icon>
              <span className="text-xs text-muted-foreground">Search</span>
            </div>
            <div className="flex flex-col items-center gap-2">
              <Icon size={IconCva.size.Xl} className={colorClass}><Menu /></Icon>
              <span className="text-xs text-muted-foreground">Menu</span>
            </div>
          </div>
        </div>
      </div>
    );
  },
}

export const Sizes: Story = {
  args: {
    color: 'text-100',
  },
  render: (args) => {
    const colorClass = colorOptions[args.color as keyof typeof colorOptions] || 'text-text-100';
    return (
      <div className="flex flex-col gap-8 p-8">
        <div>
          <h2 className="text-2xl font-bold mb-4">Icon Sizes</h2>
          <div className="flex items-end gap-4">
            <div className="flex flex-col items-center gap-2">
              <Icon size={IconCva.size.Xs} className={colorClass}><Star className="w-full h-full" /></Icon>
              <span className="text-xs text-muted-foreground">xs (12px)</span>
            </div>
            <div className="flex flex-col items-center gap-2">
              <Icon size={IconCva.size.Sm} className={colorClass}><Star className="w-full h-full" /></Icon>
              <span className="text-xs text-muted-foreground">sm (16px)</span>
            </div>
            <div className="flex flex-col items-center gap-2">
              <Icon size={IconCva.size.Md} className={colorClass}><Star className="w-full h-full" /></Icon>
              <span className="text-xs text-muted-foreground">md (20px)</span>
            </div>
            <div className="flex flex-col items-center gap-2">
              <Icon size={IconCva.size.Lg} className={colorClass}><Star className="w-full h-full" /></Icon>
              <span className="text-xs text-muted-foreground">lg (24px)</span>
            </div>
            <div className="flex flex-col items-center gap-2">
              <Icon size={IconCva.size.Xl} className={colorClass}><Star className="w-full h-full" /></Icon>
              <span className="text-xs text-muted-foreground">xl (32px)</span>
            </div>
            <div className="flex flex-col items-center gap-2">
              <Icon size={IconCva.size.Xxl} className={colorClass}><Star className="w-full h-full" /></Icon>
              <span className="text-xs text-muted-foreground">2xl (48px)</span>
            </div>
          </div>
        </div>
      </div>
    );
  },
}
