import type { StoryObj } from '@storybook/react';
declare const meta: {
    title: string;
    component: import("react").ForwardRefExoticComponent<import("../../..").IToggle & import("react").RefAttributes<HTMLButtonElement>>;
    parameters: {
        layout: string;
        backgrounds: {
            default: string;
            values: {
                name: string;
                value: string;
            }[];
        };
    };
    tags: string[];
    argTypes: {
        type: {
            control: string;
            options: string[];
            description: string;
        };
    };
};
export default meta;
type Story = StoryObj<typeof meta>;
export declare const Default: Story;
export declare const Disabled: Story;
export declare const Radio: Story;
export declare const RadioDisabled: Story;
