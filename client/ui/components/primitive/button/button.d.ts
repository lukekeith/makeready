import React from "react";
import "./button.scss";
export declare const ButtonCva: any;
export interface IButton {
    variant?: keyof typeof ButtonCva.variant;
    size?: keyof typeof ButtonCva.size;
    children?: React.ReactNode;
    className?: string;
    onClick?: () => void;
    disabled?: boolean;
    type?: "button" | "submit" | "reset";
    containerProps?: React.ButtonHTMLAttributes<HTMLButtonElement>;
}
export declare const Button: React.ForwardRefExoticComponent<IButton & React.RefAttributes<HTMLButtonElement>>;
