import type { Meta, StoryObj } from '@storybook/react'
import { Icon, IconCva } from '../../../components/primitive/icon/icon'
import { useState } from 'react'

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
  // Additional icons for the All Icons story
  Activity,
  Airplay,
  Archive,
  ArrowRight,
  ArrowLeft,
  ArrowUp,
  ArrowDown,
  AtSign,
  Award,
  BarChart,
  Battery,
  Bluetooth,
  Book,
  Bookmark,
  Box,
  Briefcase,
  Calendar,
  Camera,
  Cast,
  CheckCircle,
  ChevronLeft,
  ChevronRight,
  ChevronUp,
  Circle,
  Clipboard,
  Clock,
  Cloud,
  Code,
  Coffee,
  Command,
  Compass,
  Copy,
  CreditCard,
  Crop,
  Database,
  Delete,
  Download,
  Edit,
  ExternalLink,
  Eye,
  EyeOff,
  Facebook,
  File,
  FileText,
  Film,
  Filter,
  Flag,
  Folder,
  Gift,
  GitBranch,
  Github,
  Globe,
  Grid,
  Hash,
  Headphones,
  HelpCircle,
  Image,
  Inbox,
  Info,
  Instagram,
  Key,
  Layers,
  Layout,
  Link,
  Linkedin,
  List,
  Loader,
  Lock,
  LogIn,
  LogOut,
  Mail,
  Map,
  MapPin,
  Maximize,
  Minimize,
  MessageCircle,
  MessageSquare,
  Mic,
  MicOff,
  Monitor,
  Moon,
  MoreHorizontal,
  MoreVertical,
  Move,
  Music,
  Navigation,
  Package,
  Paperclip,
  Pause,
  Phone,
  Play,
  Power,
  Printer,
  Radio,
  RefreshCw,
  Repeat,
  RotateCw,
  Save,
  Send,
  Server,
  Share,
  Shield,
  ShoppingCart,
  Shuffle,
  Sidebar,
  SkipBack,
  SkipForward,
  Slack,
  Smartphone,
  Speaker,
  Square,
  StopCircle,
  Sun,
  Tag,
  Target,
  Terminal,
  ThumbsUp,
  ThumbsDown,
  ToggleLeft,
  ToggleRight,
  Trash,
  TrendingUp,
  TrendingDown,
  Triangle,
  Truck,
  Tv,
  Twitter,
  Type,
  Umbrella,
  Underline,
  Unlock,
  Upload,
  UserCheck,
  UserMinus,
  UserPlus,
  UserX,
  Users,
  Video,
  VideoOff,
  Voicemail,
  Volume,
  Volume1,
  Volume2,
  VolumeX,
  Watch,
  Wifi,
  WifiOff,
  Wind,
  XCircle,
  XSquare,
  Youtube,
  Zap,
  ZapOff,
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
    colorClass: {
      name: 'color',
      control: 'select',
      options: Object.keys(colorOptions),
    },
  },
} satisfies Meta<typeof Icon>

export default meta
type Story = StoryObj<typeof meta>

export const SocialIcons: Story = {
  args: {
    colorClass: 'primary-400',
  },
  render: (args) => {
    const colorClass = colorOptions[args.colorClass as keyof typeof colorOptions] || 'text-primary-400';
    return (
      <div className="flex flex-col gap-8 p-8">
        <div>
          <h2 className="text-2xl font-bold mb-4 text-foreground">Social Media Icons</h2>
          <p className="text-muted-foreground mb-6">
            Perfect for sign-in buttons and social links
          </p>

          <div className="grid grid-cols-4 gap-6">
            <div className="flex flex-col items-center gap-2">
              <Icon size={IconCva.size.Xxl} className={colorClass}>
                <FaGoogle />
              </Icon>
              <span className="text-sm text-muted-foreground">Google</span>
            </div>

            <div className="flex flex-col items-center gap-2">
              <Icon size={IconCva.size.Xxl} className={colorClass}>
                <FaFacebook />
              </Icon>
              <span className="text-sm text-muted-foreground">Facebook</span>
            </div>

            <div className="flex flex-col items-center gap-2">
              <Icon size={IconCva.size.Xxl} className={colorClass}>
                <FaApple />
              </Icon>
              <span className="text-sm text-muted-foreground">Apple</span>
            </div>

            <div className="flex flex-col items-center gap-2">
              <Icon size={IconCva.size.Xxl} className={colorClass}>
                <FaXTwitter />
              </Icon>
              <span className="text-sm text-muted-foreground">X</span>
            </div>

            <div className="flex flex-col items-center gap-2">
              <Icon size={IconCva.size.Xxl} className={colorClass}>
                <FaTwitter />
              </Icon>
              <span className="text-sm text-muted-foreground">Twitter</span>
            </div>

            <div className="flex flex-col items-center gap-2">
              <Icon size={IconCva.size.Xxl} className={colorClass}>
                <FaGithub />
              </Icon>
              <span className="text-sm text-muted-foreground">GitHub</span>
            </div>

            <div className="flex flex-col items-center gap-2">
              <Icon size={IconCva.size.Xxl} className={colorClass}>
                <FaLinkedin />
              </Icon>
              <span className="text-sm text-muted-foreground">LinkedIn</span>
            </div>

            <div className="flex flex-col items-center gap-2">
              <Icon size={IconCva.size.Xxl} className={colorClass}>
                <FaInstagram />
              </Icon>
              <span className="text-sm text-muted-foreground">Instagram</span>
            </div>
          </div>
        </div>
      </div>
    );
  },
}

export const NavigationIcons: Story = {
  args: {
    colorClass: 'primary-400',
  },
  render: (args) => {
    const colorClass = colorOptions[args.colorClass as keyof typeof colorOptions] || 'text-primary-400';
    return (
      <div className="flex flex-col gap-8 p-8">
        <div>
          <h2 className="text-2xl font-bold mb-4 text-foreground">Navigation & Menu Icons</h2>
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
    colorClass: 'primary-400',
  },
  render: (args) => {
    const colorClass = colorOptions[args.colorClass as keyof typeof colorOptions] || 'text-primary-400';
    return (
      <div className="flex flex-col gap-8 p-8">
        <div>
          <h2 className="text-2xl font-bold mb-4 text-foreground">Icon Sizes</h2>
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

export const AllLucideIcons: Story = {
  parameters: {
    layout: 'fullscreen',
  },
  args: {
    colorClass: 'primary-400',
  },
  render: (args) => {
    const colorClass = colorOptions[args.colorClass as keyof typeof colorOptions] || 'text-primary-400';
    const [searchQuery, setSearchQuery] = useState('');
    const [copiedIcon, setCopiedIcon] = useState<string | null>(null);

    // Curated list of Lucide icons with their components
    const allIconEntries: Array<[string, React.ComponentType]> = [
      ['Activity', Activity],
      ['Airplay', Airplay],
      ['AlertCircle', AlertCircle],
      ['Archive', Archive],
      ['ArrowDown', ArrowDown],
      ['ArrowLeft', ArrowLeft],
      ['ArrowRight', ArrowRight],
      ['ArrowUp', ArrowUp],
      ['AtSign', AtSign],
      ['Award', Award],
      ['BarChart', BarChart],
      ['Battery', Battery],
      ['Bell', Bell],
      ['Bluetooth', Bluetooth],
      ['Book', Book],
      ['Bookmark', Bookmark],
      ['Box', Box],
      ['Briefcase', Briefcase],
      ['Calendar', Calendar],
      ['Camera', Camera],
      ['Cast', Cast],
      ['Check', Check],
      ['CheckCircle', CheckCircle],
      ['ChevronDown', ChevronDown],
      ['ChevronLeft', ChevronLeft],
      ['ChevronRight', ChevronRight],
      ['ChevronUp', ChevronUp],
      ['Circle', Circle],
      ['Clipboard', Clipboard],
      ['Clock', Clock],
      ['Cloud', Cloud],
      ['Code', Code],
      ['Coffee', Coffee],
      ['Command', Command],
      ['Compass', Compass],
      ['Copy', Copy],
      ['CreditCard', CreditCard],
      ['Crop', Crop],
      ['Database', Database],
      ['Delete', Delete],
      ['Download', Download],
      ['Edit', Edit],
      ['ExternalLink', ExternalLink],
      ['Eye', Eye],
      ['EyeOff', EyeOff],
      ['Facebook', Facebook],
      ['File', File],
      ['FileText', FileText],
      ['Film', Film],
      ['Filter', Filter],
      ['Flag', Flag],
      ['Folder', Folder],
      ['Gift', Gift],
      ['GitBranch', GitBranch],
      ['Github', Github],
      ['Globe', Globe],
      ['Grid', Grid],
      ['Hash', Hash],
      ['Headphones', Headphones],
      ['Heart', Heart],
      ['HelpCircle', HelpCircle],
      ['Home', Home],
      ['Image', Image],
      ['Inbox', Inbox],
      ['Info', Info],
      ['Instagram', Instagram],
      ['Key', Key],
      ['Layers', Layers],
      ['Layout', Layout],
      ['Link', Link],
      ['Linkedin', Linkedin],
      ['List', List],
      ['Loader', Loader],
      ['Lock', Lock],
      ['LogIn', LogIn],
      ['LogOut', LogOut],
      ['Mail', Mail],
      ['Map', Map],
      ['MapPin', MapPin],
      ['Maximize', Maximize],
      ['Menu', Menu],
      ['MessageCircle', MessageCircle],
      ['MessageSquare', MessageSquare],
      ['Mic', Mic],
      ['MicOff', MicOff],
      ['Minimize', Minimize],
      ['Monitor', Monitor],
      ['Moon', Moon],
      ['MoreHorizontal', MoreHorizontal],
      ['MoreVertical', MoreVertical],
      ['Move', Move],
      ['Music', Music],
      ['Navigation', Navigation],
      ['Package', Package],
      ['Paperclip', Paperclip],
      ['Pause', Pause],
      ['Phone', Phone],
      ['Play', Play],
      ['Plus', Plus],
      ['Power', Power],
      ['Printer', Printer],
      ['Radio', Radio],
      ['RefreshCw', RefreshCw],
      ['Repeat', Repeat],
      ['RotateCw', RotateCw],
      ['Save', Save],
      ['Search', Search],
      ['Send', Send],
      ['Server', Server],
      ['Settings', Settings],
      ['Share', Share],
      ['Shield', Shield],
      ['ShoppingCart', ShoppingCart],
      ['Shuffle', Shuffle],
      ['Sidebar', Sidebar],
      ['SkipBack', SkipBack],
      ['SkipForward', SkipForward],
      ['Slack', Slack],
      ['Smartphone', Smartphone],
      ['Speaker', Speaker],
      ['Square', Square],
      ['Star', Star],
      ['StopCircle', StopCircle],
      ['Sun', Sun],
      ['Tag', Tag],
      ['Target', Target],
      ['Terminal', Terminal],
      ['ThumbsDown', ThumbsDown],
      ['ThumbsUp', ThumbsUp],
      ['ToggleLeft', ToggleLeft],
      ['ToggleRight', ToggleRight],
      ['Trash', Trash],
      ['TrendingDown', TrendingDown],
      ['TrendingUp', TrendingUp],
      ['Triangle', Triangle],
      ['Truck', Truck],
      ['Tv', Tv],
      ['Twitter', Twitter],
      ['Type', Type],
      ['Umbrella', Umbrella],
      ['Underline', Underline],
      ['Unlock', Unlock],
      ['Upload', Upload],
      ['User', User],
      ['UserCheck', UserCheck],
      ['UserMinus', UserMinus],
      ['UserPlus', UserPlus],
      ['Users', Users],
      ['UserX', UserX],
      ['Video', Video],
      ['VideoOff', VideoOff],
      ['Voicemail', Voicemail],
      ['Volume', Volume],
      ['Volume1', Volume1],
      ['Volume2', Volume2],
      ['VolumeX', VolumeX],
      ['Watch', Watch],
      ['Wifi', Wifi],
      ['WifiOff', WifiOff],
      ['Wind', Wind],
      ['X', X],
      ['XCircle', XCircle],
      ['XSquare', XSquare],
      ['Youtube', Youtube],
      ['Zap', Zap],
      ['ZapOff', ZapOff],
    ];

    // Filter icons based on search query
    const filteredIcons = allIconEntries.filter(([name]) => {
      if (!searchQuery) return true;
      return name.toLowerCase().includes(searchQuery.toLowerCase());
    });

    // Handle copying icon name to clipboard
    const handleCopyIconName = (name: string) => {
      navigator.clipboard.writeText(name);
      setCopiedIcon(name);
      setTimeout(() => setCopiedIcon(null), 2000);
    };

    return (
      <div className="min-h-screen p-8 flex flex-col">
        <div className="max-w-[1400px] mx-auto w-full flex-1 flex flex-col">
          {/* Header */}
          <div className="mb-8">
            <h2 className="text-3xl font-bold mb-2 text-foreground">Lucide Icons</h2>
            <p className="text-muted-foreground">
              {filteredIcons.length} {filteredIcons.length === 1 ? 'icon' : 'icons'}
              {searchQuery && ` matching "${searchQuery}"`}
              {!searchQuery && ` available from lucide-react`}
            </p>
          </div>

          {/* Search Bar */}
          <div className="mb-8 relative">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-muted-foreground" />
            <input
              type="text"
              placeholder="Search icons..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-10 pr-4 py-3 bg-background border border-input rounded-lg text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring"
            />
            {searchQuery && (
              <button
                onClick={() => setSearchQuery('')}
                className="absolute right-3 top-1/2 transform -translate-y-1/2 text-muted-foreground hover:text-foreground"
              >
                <X className="w-5 h-5" />
              </button>
            )}
          </div>
        </div>

        {/* Icons Grid */}
        {filteredIcons.length > 0 ? (
          <div className="grid grid-cols-4 sm:grid-cols-6 md:grid-cols-8 lg:grid-cols-10 gap-4">
            {filteredIcons.map(([name, IconComponent]) => {
              const isCopied = copiedIcon === name;

              return (
                <button
                  key={name}
                  onClick={() => handleCopyIconName(name)}
                  className="flex flex-col items-center gap-2 p-3 hover:bg-muted rounded-lg transition-all duration-200 cursor-pointer group relative"
                  title={`Click to copy: ${name}`}
                >
                  <div className="relative">
                    <Icon size={IconCva.size.Lg} className={colorClass}>
                      <IconComponent />
                    </Icon>
                    {isCopied && (
                      <div className="absolute -top-8 left-1/2 transform -translate-x-1/2 bg-foreground text-background text-xs px-2 py-1 rounded whitespace-nowrap">
                        Copied!
                      </div>
                    )}
                  </div>
                  <span className="text-xs text-muted-foreground text-center break-words w-full group-hover:text-foreground transition-colors">
                    {name}
                  </span>
                </button>
              );
            })}
          </div>
        ) : (
          <div className="text-center py-16">
            <AlertCircle className="w-12 h-12 mx-auto mb-4 text-muted-foreground" />
            <p className="text-lg text-muted-foreground">
              No icons found matching "{searchQuery}"
            </p>
            <button
              onClick={() => setSearchQuery('')}
              className="mt-4 px-4 py-2 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors"
            >
              Clear search
            </button>
          </div>
        )}

          {/* Footer Info */}
          <div className="mt-8 pt-6 border-t border-border">
            <p className="text-sm text-muted-foreground">
              Click any icon to copy its name to clipboard. Import icons from lucide-react:
            </p>
            <code className="block mt-2 p-3 bg-muted rounded-lg text-sm font-mono">
              import &#123; {filteredIcons.slice(0, 3).map(([name]) => name).join(', ')} &#125; from 'lucide-react'
            </code>
          </div>
        </div>
      </div>
    );
  },
}
