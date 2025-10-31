import React from "react";
import { IButton } from "../button/button";
import "./social-button.scss";
type SocialProvider = 'google' | 'facebook' | 'apple' | 'twitter' | 'github';
export interface ISocialButton extends IButton {
    provider: SocialProvider;
    label?: string;
}
export declare const SocialButton: React.ForwardRefExoticComponent<ISocialButton & React.RefAttributes<HTMLButtonElement>>;
export {};
