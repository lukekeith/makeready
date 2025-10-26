import { observer } from "mobx-react";
import React from "react";
import { cva, VariantProps } from "util/cva";
import { classnames } from "util/classnames";
import logoMark from "../../../assets/images/logo-mark.svg";

export const AuthLayoutCva = cva("", {
  variants: {
    layout: {
      Centered: "",
      Split: "",
      Minimal: "",
    },
  },
  defaultVariants: {
    layout: "Centered",
  },
});

export interface IAuthLayout {
  layout?: keyof typeof AuthLayoutCva.layout;
  children?: React.ReactNode;
  className?: string;
  title?: string;
  description?: string;
  showTerms?: boolean;
  termsUrl?: string;
  privacyUrl?: string;
  showBranding?: boolean;
  brandingQuote?: string;
  brandingAuthor?: string;
  socialButtons?: React.ReactNode;
  emailForm?: React.ReactNode;
}

export const AuthLayout = observer((props: IAuthLayout) => {
  const {
    children,
    className,
    layout = AuthLayoutCva.defaults?.layout,
    title = "Create an account",
    description = "Enter your email below to create your account",
    showTerms = true,
    termsUrl = "/terms",
    privacyUrl = "/privacy",
    showBranding = false,
    brandingQuote = "Preparing men for the future, to become leaders in their families and communities.",
    brandingAuthor = "Scott Stickane",
    socialButtons,
    emailForm,
  } = props;

  const renderContent = () => (
    <div className="mx-auto flex w-full flex-col justify-center space-y-6 sm:w-[350px]">
      <div className="flex flex-col space-y-2 text-center">
        <h1 className={layout === "Minimal" ? "text-3xl font-bold tracking-tight" : "text-2xl font-semibold tracking-tight"}>
          {title}
        </h1>
        <p className="text-sm text-muted-foreground">
          {description}
        </p>
      </div>

      {emailForm}

      {children}

      {socialButtons && (
        <div className="grid gap-2">
          {socialButtons}
        </div>
      )}

      {showTerms && (
        <p className="px-8 text-center text-xs text-muted-foreground">
          By clicking continue, you agree to our{' '}
          <a
            href={termsUrl}
            className="underline underline-offset-4 hover:text-primary"
          >
            Terms of Service
          </a>{' '}
          and{' '}
          <a
            href={privacyUrl}
            className="underline underline-offset-4 hover:text-primary"
          >
            Privacy Policy
          </a>
          .
        </p>
      )}
    </div>
  );

  const renderBranding = () => (
    <div className="relative hidden h-full flex-col bg-muted p-10 text-white lg:flex dark:border-r">
      <div className="absolute inset-0 bg-zinc-900" />
      <div className="relative z-20 flex items-center text-lg font-medium">
        <img
          src={logoMark}
          alt="MakeReady Logo"
          className="mr-2 h-6 w-6"
        />
        MakeReady
      </div>
      <div className="relative z-20 mt-auto">
        <blockquote className="space-y-2">
          <p className="text-lg">
            {brandingQuote}
          </p>
          <footer className="text-sm">{brandingAuthor}</footer>
        </blockquote>
      </div>
    </div>
  );

  if (layout === "Split") {
    return (
      <div className={classnames(
        "container relative min-h-screen flex-col items-center justify-center grid lg:max-w-none lg:grid-cols-2 lg:px-0",
        className
      )}>
        {showBranding && renderBranding()}
        <div className="lg:p-8">
          {renderContent()}
        </div>
      </div>
    );
  }

  if (layout === "Minimal") {
    return (
      <div className={classnames(
        "min-h-screen flex items-center justify-center p-4",
        className
      )}>
        <div className="mx-auto flex w-full flex-col justify-center space-y-6 sm:w-[350px]">
          <div className="flex flex-col space-y-2 text-center">
            <h1 className="text-3xl font-bold tracking-tight">
              {title}
            </h1>
            <p className="text-sm text-muted-foreground">
              {description}
            </p>
          </div>

          {emailForm}

          {children}

          {socialButtons && (
            <div className="grid gap-2">
              {socialButtons}
            </div>
          )}
        </div>
      </div>
    );
  }

  // Default: Centered layout
  return (
    <div className={classnames(
      "min-h-screen flex items-center justify-center p-4",
      className
    )}>
      {renderContent()}
    </div>
  );
});

AuthLayout.displayName = "AuthLayout";
