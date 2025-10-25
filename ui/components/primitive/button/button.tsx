import { observer } from "mobx-react";
import React from "react";
import { cva, VariantProps } from "util/cva";
import { classnames } from "util/classnames";
import "./button.scss";

export const ButtonCva = cva("Button", {
  variants: {
    variant: {
      Default: "Button--default",
      Destructive: "Button--destructive",
      Outline: "Button--outline",
      Secondary: "Button--secondary",
      Ghost: "Button--ghost",
      Link: "Button--link",
    },
    size: {
      Default: "Button--size-default",
      Sm: "Button--size-sm",
      Lg: "Button--size-lg",
      Icon: "Button--size-icon",
    },
  },
  defaultVariants: {
    variant: "Default",
    size: "Default",
  },
});

export interface IButton extends VariantProps<typeof ButtonCva.variants> {
  children?: React.ReactNode;
  className?: string;
  onClick?: () => void;
  disabled?: boolean;
  type?: "button" | "submit" | "reset";
  containerProps?: React.ButtonHTMLAttributes<HTMLButtonElement>;
}

export const Button = observer(
  React.forwardRef<HTMLButtonElement, IButton>((props, ref) => {
    const {
      children,
      className,
      variant = ButtonCva.defaults?.variant,
      size = ButtonCva.defaults?.size,
      onClick,
      disabled,
      type = "button",
      containerProps,
    } = props;

    return (
      <button
        ref={ref}
        type={type}
        className={classnames(
          ButtonCva.variants({ variant, size }),
          className
        )}
        onClick={onClick}
        disabled={disabled}
        {...containerProps}
      >
        {children}
      </button>
    );
  })
);

Button.displayName = "Button";
