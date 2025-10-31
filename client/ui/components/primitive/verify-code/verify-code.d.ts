import React from "react";
import { VariantProps } from "util/cva";
import "./verify-code.scss";
export declare const VerifyCodeCva: any;
export interface IVerifyCode extends VariantProps<typeof VerifyCodeCva.variants> {
    className?: string;
    containerProps?: React.HTMLAttributes<HTMLDivElement>;
    value?: string;
    onChange?: (code: string) => void;
    onComplete?: (code: string) => void;
    length?: number;
    disabled?: boolean;
    autoFocus?: boolean;
}
export declare const VerifyCode: React.ForwardRefExoticComponent<IVerifyCode & React.RefAttributes<HTMLDivElement>>;
