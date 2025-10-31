import React from "react";
import "./icon.scss";
export declare const IconCva: any;
export interface IIcon {
    size?: keyof typeof IconCva.size;
    children: React.ReactNode;
    className?: string;
    containerProps?: React.HTMLAttributes<HTMLSpanElement>;
}
export declare const Icon: React.ForwardRefExoticComponent<IIcon & React.RefAttributes<HTMLSpanElement>>;
