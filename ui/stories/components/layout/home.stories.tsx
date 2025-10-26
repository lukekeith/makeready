import type { Meta, StoryObj } from "@storybook/react";
import {
  HomeLayout,
  HomeLayoutCva,
} from "../../../components/layout/home/home";
import { Avatar, AvatarImage, AvatarFallback, Button } from "../../../index";

const meta = {
  title: "Layout/Home",
  component: HomeLayout,
  parameters: {
    layout: "fullscreen",
  },
  tags: ["autodocs"],
  argTypes: {
    spacing: {
      control: "select",
      options: Object.keys(HomeLayoutCva.spacing),
    },
    centerContent: {
      control: "boolean",
    },
  },
} satisfies Meta<typeof HomeLayout>;

export default meta;
type Story = StoryObj<typeof meta>;

const mockUser = {
  name: "John Doe",
  email: "john@example.com",
  picture: "https://i.pravatar.cc/150?img=12",
};

export const Default: Story = {
  args: {
    spacing: HomeLayoutCva.spacing.Comfortable,
    title: "MakeReady Admin",
    children: (
      <div>
        <h2 className="text-2xl font-bold mb-4">Dashboard</h2>
        <p className="text-muted-foreground">Welcome to your dashboard.</p>
      </div>
    ),
  },
};

export const WithUser: Story = {
  args: {
    spacing: HomeLayoutCva.spacing.Comfortable,
    title: "MakeReady Admin",
    user: mockUser,
    children: (
      <div>
        <h2 className="text-2xl font-bold mb-4">Dashboard</h2>
        <p className="text-muted-foreground">Logged in as {mockUser.name}</p>
      </div>
    ),
  },
};

export const WithAvatar: Story = {
  args: {
    spacing: HomeLayoutCva.spacing.Comfortable,
    title: "MakeReady Admin",
    user: mockUser,
    avatar: (
      <Avatar>
        <AvatarImage src={mockUser.picture} alt={mockUser.name} />
        <AvatarFallback>{mockUser.name.charAt(0).toUpperCase()}</AvatarFallback>
      </Avatar>
    ),
    children: (
      <div>
        <h2 className="text-2xl font-bold mb-4">Dashboard</h2>
        <p className="text-muted-foreground">Logged in as {mockUser.name}</p>
      </div>
    ),
  },
};

export const WithHeaderActions: Story = {
  args: {
    spacing: HomeLayoutCva.spacing.Comfortable,
    title: "MakeReady Admin",
    user: mockUser,
    avatar: (
      <Avatar>
        <AvatarImage src={mockUser.picture} alt={mockUser.name} />
        <AvatarFallback>{mockUser.name.charAt(0).toUpperCase()}</AvatarFallback>
      </Avatar>
    ),
    headerActions: (
      <Button size="sm" variant="destructive">
        Logout
      </Button>
    ),
    children: (
      <div>
        <h2 className="text-2xl font-bold mb-4">Dashboard</h2>
        <p className="text-muted-foreground">Logged in as {mockUser.name}</p>
      </div>
    ),
  },
};

export const CenteredContent: Story = {
  args: {
    spacing: HomeLayoutCva.spacing.Comfortable,
    title: "MakeReady Admin",
    user: mockUser,
    avatar: (
      <Avatar>
        <AvatarImage src={mockUser.picture} alt={mockUser.name} />
        <AvatarFallback>{mockUser.name.charAt(0).toUpperCase()}</AvatarFallback>
      </Avatar>
    ),
    centerContent: true,
    children: (
      <div className="text-center">
        <h2 className="text-3xl font-bold mb-4">Welcome, {mockUser.name}!</h2>
        <p className="text-muted-foreground mb-8">
          You are successfully authenticated.
        </p>
        <p className="text-sm text-muted-foreground">
          Logged in as: {mockUser.email}
        </p>
      </div>
    ),
  },
};

export const CompactSpacing: Story = {
  args: {
    spacing: HomeLayoutCva.spacing.Compact,
    title: "MakeReady Admin",
    user: mockUser,
    avatar: (
      <Avatar>
        <AvatarImage src={mockUser.picture} alt={mockUser.name} />
        <AvatarFallback>{mockUser.name.charAt(0).toUpperCase()}</AvatarFallback>
      </Avatar>
    ),
    children: (
      <div>
        <h2 className="text-2xl font-bold mb-2">Compact Layout</h2>
        <p className="text-muted-foreground">Less padding for dense UIs.</p>
      </div>
    ),
  },
};
