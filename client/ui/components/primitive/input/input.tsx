import { observer } from "mobx-react";
import React from "react";
import { classnames } from "util";

export interface IInput extends React.InputHTMLAttributes<HTMLInputElement> {
  className?: string;
}

export const Input = observer(
  React.forwardRef<HTMLInputElement, IInput>((props, ref) => {
    const { className, type = "text", ...restProps } = props;

    return (
      <input
        ref={ref}
        type={type}
        className={classnames(
          "flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50",
          className
        )}
        {...restProps}
      />
    );
  })
);

Input.displayName = "Input";
