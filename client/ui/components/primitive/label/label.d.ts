import React from "react";
export interface ILabel extends React.LabelHTMLAttributes<HTMLLabelElement> {
    className?: string;
}
export declare const Label: React.ForwardRefExoticComponent<ILabel & React.RefAttributes<HTMLLabelElement>>;
