import { observer } from "mobx-react";
import React from "react";
import { classnames } from "util";

export interface ILabel extends React.LabelHTMLAttributes<HTMLLabelElement> {
  className?: string;
}

export const Label = observer(
  React.forwardRef<HTMLLabelElement, ILabel>((props, ref) => {
    const { className, ...restProps } = props;

    return (
      <label
        ref={ref}
        className={classnames(
          "text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70",
          className
        )}
        {...restProps}
      />
    );
  })
);

Label.displayName = "Label";
