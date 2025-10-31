import type { StoryObj } from '@storybook/react';
declare const meta: {
    title: string;
    component: import("react").ForwardRefExoticComponent<import("../../..").ISocialButton & import("react").RefAttributes<HTMLButtonElement>>;
    parameters: {
        layout: string;
    };
    tags: string[];
    argTypes: {
        provider: {
            control: "select";
            options: string[];
        };
        variant: {
            control: "select";
            options: string[];
        };
    };
};
export default meta;
type Story = StoryObj<typeof meta>;
export declare const Google: Story;
export declare const Facebook: Story;
export declare const Apple: Story;
export declare const Twitter: Story;
export declare const GitHub: Story;
export declare const CustomLabel: Story;
export declare const SignInPage: Story;
export declare const AllProviders: Story;
