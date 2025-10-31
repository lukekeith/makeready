import type { StoryObj } from '@storybook/react';
declare const meta: {
    title: string;
    component: import("react").ForwardRefExoticComponent<import("../../..").IVerifyCode & import("react").RefAttributes<HTMLDivElement>>;
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
        size: {
            control: string;
            options: string[];
            description: string;
        };
        length: {
            control: {
                type: "number";
                min: number;
                max: number;
            };
            description: string;
        };
        disabled: {
            control: "boolean";
            description: string;
        };
    };
};
export default meta;
type Story = StoryObj<typeof meta>;
export declare const Default: Story;
export declare const Disabled: Story;
export declare const Large: Story;
export declare const FourDigit: Story;
