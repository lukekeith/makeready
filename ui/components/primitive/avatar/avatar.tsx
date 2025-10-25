import { observer } from "mobx-react";
import React from "react";
import * as AvatarPrimitive from "@radix-ui/react-avatar";
import { classnames } from "util";
import "./avatar.scss";

export interface IAvatar extends React.ComponentPropsWithoutRef<typeof AvatarPrimitive.Root> {
  className?: string;
}

export const Avatar = observer(
  React.forwardRef<React.ElementRef<typeof AvatarPrimitive.Root>, IAvatar>(
    (props, ref) => {
      const { className, ...restProps } = props;

      return (
        <AvatarPrimitive.Root
          ref={ref}
          className={classnames("Avatar", className)}
          {...restProps}
        />
      );
    }
  )
);

Avatar.displayName = "Avatar";

export interface IAvatarImage extends React.ComponentPropsWithoutRef<typeof AvatarPrimitive.Image> {
  className?: string;
}

export const AvatarImage = observer(
  React.forwardRef<React.ElementRef<typeof AvatarPrimitive.Image>, IAvatarImage>(
    (props, ref) => {
      const { className, ...restProps } = props;

      return (
        <AvatarPrimitive.Image
          ref={ref}
          className={classnames("Avatar__image", className)}
          {...restProps}
        />
      );
    }
  )
);

AvatarImage.displayName = "AvatarImage";

export interface IAvatarFallback extends React.ComponentPropsWithoutRef<typeof AvatarPrimitive.Fallback> {
  className?: string;
}

export const AvatarFallback = observer(
  React.forwardRef<React.ElementRef<typeof AvatarPrimitive.Fallback>, IAvatarFallback>(
    (props, ref) => {
      const { className, ...restProps } = props;

      return (
        <AvatarPrimitive.Fallback
          ref={ref}
          className={classnames("Avatar__fallback", className)}
          {...restProps}
        />
      );
    }
  )
);

AvatarFallback.displayName = "AvatarFallback";
