import type { StoryObj } from '@storybook/react';
declare const meta: {
    title: string;
    parameters: {
        layout: string;
    };
    tags: string[];
};
export default meta;
type Story = StoryObj<typeof meta>;
export declare const CenteredCard: Story;
export declare const SplitLayout: Story;
export declare const MinimalCenter: Story;
export declare const SplitLayoutGoogleOnly: Story;
