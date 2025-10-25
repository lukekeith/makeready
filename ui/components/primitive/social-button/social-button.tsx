import { observer } from "mobx-react";
import React from "react";
import { Button, ButtonCva, IButton } from "../button/button";
import { Icon, IconCva } from "../icon/icon";
import { FaGoogle, FaFacebook, FaApple, FaGithub } from 'react-icons/fa';
import { FaXTwitter } from 'react-icons/fa6';
import { classnames } from "util/classnames";
import "./social-button.scss";

type SocialProvider = 'google' | 'facebook' | 'apple' | 'twitter' | 'github';

const socialIcons = {
  google: FaGoogle,
  facebook: FaFacebook,
  apple: FaApple,
  twitter: FaXTwitter,
  github: FaGithub,
};

const socialLabels = {
  google: 'Google',
  facebook: 'Facebook',
  apple: 'Apple',
  twitter: 'X',
  github: 'GitHub',
};

export interface ISocialButton extends Omit<IButton, 'children'> {
  provider: SocialProvider;
  label?: string;
}

export const SocialButton = observer(
  React.forwardRef<HTMLButtonElement, ISocialButton>((props, ref) => {
    const {
      provider,
      label,
      variant = ButtonCva.variant.Outline,
      className,
      ...restProps
    } = props;

    const IconComponent = socialIcons[provider];
    const defaultLabel = socialLabels[provider];

    return (
      <Button
        ref={ref}
        variant={variant}
        className={classnames("SocialButton", className)}
        {...restProps}
      >
        <Icon size={IconCva.size.Lg}>
          <IconComponent />
        </Icon>
        <span className="SocialButton__text">
          {label || `Sign up with ${defaultLabel}`}
        </span>
      </Button>
    );
  })
);

SocialButton.displayName = "SocialButton";
