import { observer } from "mobx-react";
import React, { useRef, useState, useEffect } from "react";
import { cva, VariantProps } from "util/cva";
import { classnames } from "util/classnames";
import "./verify-code.scss";

export const VerifyCodeCva = cva("VerifyCode", {
  variants: {
    size: {
      Default: "VerifyCode--size-default",
      Large: "VerifyCode--size-large",
    },
  },
  defaultVariants: {
    size: "Default",
  },
});

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

export const VerifyCode = observer(
  React.forwardRef<HTMLDivElement, IVerifyCode>((props, ref) => {
    const {
      className,
      size = VerifyCodeCva.defaults?.size,
      containerProps,
      value = "",
      onChange,
      onComplete,
      length = 6,
      disabled = false,
      autoFocus = false,
    } = props;

    const [code, setCode] = useState<string[]>(
      value.split("").slice(0, length).concat(Array(length).fill("")).slice(0, length)
    );
    const inputRefs = useRef<(HTMLInputElement | null)[]>([]);

    // Update code when value prop changes
    useEffect(() => {
      const newCode = value.split("").slice(0, length).concat(Array(length).fill("")).slice(0, length);
      setCode(newCode);
    }, [value, length]);

    // Auto-focus first input
    useEffect(() => {
      if (autoFocus && inputRefs.current[0]) {
        inputRefs.current[0].focus();
      }
    }, [autoFocus]);

    const handleChange = (index: number, inputValue: string) => {
      // Only allow digits
      const digit = inputValue.replace(/[^0-9]/g, "");

      if (digit.length === 0) return;

      const newCode = [...code];
      newCode[index] = digit[0];
      setCode(newCode);

      const codeString = newCode.join("");
      onChange?.(codeString);

      // Check if complete
      if (newCode.every((d) => d !== "")) {
        onComplete?.(codeString);
      }

      // Move to next input
      if (index < length - 1 && digit.length > 0) {
        inputRefs.current[index + 1]?.focus();
      }
    };

    const handleKeyDown = (index: number, e: React.KeyboardEvent<HTMLInputElement>) => {
      if (e.key === "Backspace") {
        e.preventDefault();
        const newCode = [...code];

        if (code[index]) {
          // Clear current digit
          newCode[index] = "";
          setCode(newCode);
          onChange?.(newCode.join(""));
        } else if (index > 0) {
          // Move to previous and clear
          newCode[index - 1] = "";
          setCode(newCode);
          onChange?.(newCode.join(""));
          inputRefs.current[index - 1]?.focus();
        }
      } else if (e.key === "ArrowLeft" && index > 0) {
        inputRefs.current[index - 1]?.focus();
      } else if (e.key === "ArrowRight" && index < length - 1) {
        inputRefs.current[index + 1]?.focus();
      }
    };

    const handlePaste = (e: React.ClipboardEvent) => {
      e.preventDefault();
      const pastedData = e.clipboardData.getData("text").replace(/[^0-9]/g, "");
      const digits = pastedData.split("").slice(0, length);
      const newCode = digits.concat(Array(length).fill("")).slice(0, length);
      setCode(newCode);

      const codeString = newCode.join("");
      onChange?.(codeString);

      if (newCode.every((d) => d !== "")) {
        onComplete?.(codeString);
      }

      // Focus last filled input or first empty
      const lastFilledIndex = digits.length - 1;
      if (lastFilledIndex >= 0 && lastFilledIndex < length) {
        inputRefs.current[Math.min(lastFilledIndex + 1, length - 1)]?.focus();
      }
    };

    const handleFocus = (e: React.FocusEvent<HTMLInputElement>) => {
      e.target.select();
    };

    return (
      <div
        ref={ref}
        className={classnames(VerifyCodeCva.variants({ size }), className)}
        {...containerProps}
      >
        {Array.from({ length }).map((_, index) => (
          <input
            key={index}
            ref={(el) => (inputRefs.current[index] = el)}
            type="text"
            inputMode="numeric"
            pattern="[0-9]*"
            maxLength={1}
            className="VerifyCode__input"
            value={code[index] || ""}
            onChange={(e) => handleChange(index, e.target.value)}
            onKeyDown={(e) => handleKeyDown(index, e)}
            onPaste={handlePaste}
            onFocus={handleFocus}
            disabled={disabled}
            aria-label={`Digit ${index + 1}`}
          />
        ))}
      </div>
    );
  })
);

VerifyCode.displayName = "VerifyCode";
