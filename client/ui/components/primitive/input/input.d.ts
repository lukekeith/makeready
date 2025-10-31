import React from "react";
export interface IInput extends React.InputHTMLAttributes<HTMLInputElement> {
    className?: string;
}
export declare const Input: React.ForwardRefExoticComponent<IInput & React.RefAttributes<HTMLInputElement>>;
