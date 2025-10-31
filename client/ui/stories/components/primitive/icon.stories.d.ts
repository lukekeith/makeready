import type { StoryObj } from '@storybook/react';
declare const meta: {
    title: string;
    component: import("react").ForwardRefExoticComponent<import("../../..").IIcon & import("react").RefAttributes<HTMLSpanElement>>;
    parameters: {
        layout: string;
    };
    tags: string[];
    argTypes: {
        size: {
            control: "select";
            options: string[];
        };
        colorClass: {
            name: string;
            control: string;
            options: string[];
        };
    };
};
export default meta;
type Story = StoryObj<typeof meta>;
export declare const SocialIcons: Story;
export declare const NavigationIcons: Story;
export declare const Sizes: Story;
export declare const AllLucideIcons: Story;
