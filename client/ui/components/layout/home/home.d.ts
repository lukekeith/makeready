import React from "react";
import "./home.scss";
export declare const HomeLayoutCva: any;
export interface IUser {
    name: string;
    email?: string;
    picture?: string;
}
export interface IHomeLayout {
    spacing?: keyof typeof HomeLayoutCva.spacing;
    children?: React.ReactNode;
    className?: string;
    containerProps?: React.HTMLAttributes<HTMLDivElement>;
    title?: string;
    logo?: string;
    user?: IUser;
    avatar?: React.ReactNode;
    headerActions?: React.ReactNode;
    centerContent?: boolean;
}
export declare const HomeLayout: React.ForwardRefExoticComponent<IHomeLayout & React.RefAttributes<HTMLDivElement>>;
