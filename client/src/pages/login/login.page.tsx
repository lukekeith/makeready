import React from 'react'
import { observer } from 'mobx-react'
import { Application } from '@/store/ApplicationStore'
import { AuthLayout, SocialButton } from 'ui'

export const LoginPage = observer(() => {
  const store = Application.ui.login

  return (
    <AuthLayout
      layout="Split"
      title="Welcome to MakeReady"
      description="Sign in with your Google account to continue"
      showBranding={true}
      socialButtons={
        <SocialButton
          provider="google"
          disabled={store.isLoading}
          onClick={() => store.handleSocialLogin('google')}
        />
      }
    />
  )
})

LoginPage.displayName = 'LoginPage'
