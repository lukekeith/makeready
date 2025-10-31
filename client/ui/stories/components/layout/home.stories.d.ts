import type { StoryObj } from "@storybook/react";
declare const meta: {
    title: string;
    component: import("react").ForwardRefExoticComponent<import("../../../index").IHomeLayout & import("react").RefAttributes<HTMLDivElement>>;
    parameters: {
        layout: string;
    };
    tags: string[];
    argTypes: {
        spacing: {
            control: "select";
            options: string[];
        };
        centerContent: {
            control: "boolean";
        };
    };
};
export default meta;
type Story = StoryObj<typeof meta>;
export declare const Default: Story;
export declare const WithUser: Story;
export declare const WithAvatar: Story;
export declare const WithHeaderActions: Story;
export declare const CenteredContent: Story;
export declare const CompactSpacing: Story;
