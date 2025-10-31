import React from "react";
import * as AvatarPrimitive from "@radix-ui/react-avatar";
import "./avatar.scss";
export interface IAvatar extends React.ComponentPropsWithoutRef<typeof AvatarPrimitive.Root> {
    className?: string;
}
export declare const Avatar: React.ForwardRefExoticComponent<IAvatar & React.RefAttributes<HTMLSpanElement>>;
export interface IAvatarImage extends React.ComponentPropsWithoutRef<typeof AvatarPrimitive.Image> {
    className?: string;
}
export declare const AvatarImage: React.ForwardRefExoticComponent<IAvatarImage & React.RefAttributes<HTMLImageElement>>;
export interface IAvatarFallback extends React.ComponentPropsWithoutRef<typeof AvatarPrimitive.Fallback> {
    className?: string;
}
export declare const AvatarFallback: React.ForwardRefExoticComponent<IAvatarFallback & React.RefAttributes<HTMLSpanElement>>;
