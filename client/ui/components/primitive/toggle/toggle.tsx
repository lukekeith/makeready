import { observer } from "mobx-react";
import React from "react";
import { cva, VariantProps } from "util/cva";
import { classnames } from "util/classnames";
import "./toggle.scss";

export const ToggleCva = cva("Toggle", {
  variants: {
    enabled: {
      True: "Toggle--enabled",
      False: "Toggle--disabled",
    },
    type: {
      Default: "Toggle--default",
      Radio: "Toggle--radio",
    },
  },
  defaultVariants: {
    enabled: "True",
    type: "Default",
  },
});

export interface IToggle extends VariantProps<typeof ToggleCva.variants> {
  className?: string;
  containerProps?: React.ButtonHTMLAttributes<HTMLButtonElement>;
  onChange?: (enabled: boolean) => void;
  disabled?: boolean;
}

export const Toggle = observer(
  React.forwardRef<HTMLButtonElement, IToggle>((props, ref) => {
    const {
      className,
      enabled = ToggleCva.defaults?.enabled,
      type = ToggleCva.defaults?.type,
      containerProps,
      onChange,
      disabled = false,
    } = props;

    const isEnabled = enabled === ToggleCva.enabled.True;

    const handleClick = () => {
      if (!disabled && onChange) {
        onChange(!isEnabled);
      }
    };

    return (
      <button
        ref={ref}
        type="button"
        className={classnames(
          ToggleCva.variants({ enabled, type }),
          className
        )}
        onClick={handleClick}
        disabled={disabled}
        role={type === ToggleCva.type.Radio ? "radio" : "switch"}
        aria-checked={isEnabled}
        {...containerProps}
      >
        <div className="Toggle__knob" />
      </button>
    );
  })
);

Toggle.displayName = "Toggle";
