import React from "react";
export declare const AuthLayoutCva: any;
export interface IAuthLayout {
    layout?: keyof typeof AuthLayoutCva.layout;
    children?: React.ReactNode;
    className?: string;
    title?: string;
    description?: string;
    showTerms?: boolean;
    termsUrl?: string;
    privacyUrl?: string;
    showBranding?: boolean;
    brandingQuote?: string;
    brandingAuthor?: string;
    socialButtons?: React.ReactNode;
    emailForm?: React.ReactNode;
}
export declare const AuthLayout: (props: IAuthLayout) => import("react/jsx-runtime").JSX.Element;
