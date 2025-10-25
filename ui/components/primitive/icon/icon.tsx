import { observer } from "mobx-react";
import React from "react";
import { cva, VariantProps } from "util/cva";
import { classnames } from "util/classnames";
import "./icon.scss";

export const IconCva = cva("Icon", {
  variants: {
    size: {
      Xs: "Icon--xs",
      Sm: "Icon--sm",
      Md: "Icon--md",
      Lg: "Icon--lg",
      Xl: "Icon--xl",
      Xxl: "Icon--2xl",
    },
  },
  defaultVariants: {
    size: "Md",
  },
});

export interface IIcon extends VariantProps<typeof IconCva.variants> {
  children: React.ReactNode;
  className?: string;
  containerProps?: React.HTMLAttributes<HTMLSpanElement>;
}

export const Icon = observer(
  React.forwardRef<HTMLSpanElement, IIcon>((props, ref) => {
    const {
      children,
      className,
      size = IconCva.defaults?.size,
      containerProps,
    } = props;

    return (
      <span
        ref={ref}
        className={classnames(IconCva.variants({ size }), className)}
        {...containerProps}
      >
        {children}
      </span>
    );
  })
);

Icon.displayName = "Icon";
