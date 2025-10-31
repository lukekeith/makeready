import type { StoryObj } from '@storybook/react';
declare const meta: {
    title: string;
    component: import("react").ForwardRefExoticComponent<import("../../..").IAvatar & import("react").RefAttributes<HTMLSpanElement>>;
    parameters: {
        layout: string;
    };
    tags: string[];
};
export default meta;
type Story = StoryObj<typeof meta>;
export declare const Default: Story;
export declare const Fallback: Story;
export declare const CustomSize: Story;
export declare const AvatarGroup: Story;
export declare const WithColoredFallbacks: Story;
export declare const Rounded: Story;
