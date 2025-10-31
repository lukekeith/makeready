import React from "react";
import { VariantProps } from "util/cva";
import "./toggle.scss";
export declare const ToggleCva: any;
export interface IToggle extends VariantProps<typeof ToggleCva.variants> {
    className?: string;
    containerProps?: React.ButtonHTMLAttributes<HTMLButtonElement>;
    onChange?: (enabled: boolean) => void;
    disabled?: boolean;
}
export declare const Toggle: React.ForwardRefExoticComponent<IToggle & React.RefAttributes<HTMLButtonElement>>;
