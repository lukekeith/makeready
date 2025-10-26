import { observer } from "mobx-react";
import React from "react";
import { cva, VariantProps } from "util/cva";
import { classnames } from "util/classnames";
import { when } from "util/when";
import "./home.scss";

export const HomeLayoutCva = cva("HomeLayout", {
  variants: {
    spacing: {
      Comfortable: "HomeLayout--comfortable",
      Compact: "HomeLayout--compact",
    },
  },
  defaultVariants: {
    spacing: "Comfortable",
  },
});

export interface IUser {
  name: string;
  email?: string;
  picture?: string;
}

export interface IHomeLayout {
  spacing?: keyof typeof HomeLayoutCva.spacing;
  children?: React.ReactNode;
  className?: string;
  containerProps?: React.HTMLAttributes<HTMLDivElement>;

  // Header props
  title?: string;
  user?: IUser;
  avatar?: React.ReactNode;
  headerActions?: React.ReactNode;

  // Content props
  centerContent?: boolean;
}

export const HomeLayout = observer(
  React.forwardRef<HTMLDivElement, IHomeLayout>((props, ref) => {
    const {
      children,
      className,
      containerProps,
      title = "MakeReady Admin",
      user,
      avatar,
      headerActions,
      centerContent = false,
    } = props;

    const spacing = props.spacing ?? HomeLayoutCva.defaults?.spacing;

    return (
      <div
        ref={ref}
        className={classnames(
          HomeLayoutCva.variants({ spacing }),
          "min-h-screen bg-background",
          className
        )}
        {...containerProps}
      >
        {/* Header */}
        <header className="HomeLayout__header border-b border-border">
          <div className="container flex items-center justify-between h-16 px-4">
            <h1 className="text-xl font-semibold">{title}</h1>

            <div className="flex items-center gap-4">
              {when(
                !!(user && !avatar),
                <span className="text-sm text-muted-foreground hidden sm:block">
                  {user?.name}
                </span>
              )}
              {avatar}
              {headerActions}
            </div>
          </div>
        </header>

        {/* Main content */}
        <main className={classnames(
          "HomeLayout__main",
          spacing === "Comfortable" ? "container px-4 py-8" : "container px-2 py-4",
          centerContent && "flex flex-col items-center justify-center min-h-[80vh]"
        )}>
          {children}
        </main>
      </div>
    );
  })
);

HomeLayout.displayName = "HomeLayout";
