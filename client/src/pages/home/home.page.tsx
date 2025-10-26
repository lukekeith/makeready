import React, { useEffect, useState } from 'react'
import { observer } from 'mobx-react'
import { Navigate } from 'react-router-dom'
import { Application } from '@/store/ApplicationStore'
import { HomeLayout, Avatar, AvatarImage, AvatarFallback, Button } from 'ui'
import { when } from 'util'

export const HomePage = observer(() => {
  const { user } = Application.session
  const { checkAuth } = Application.domain.auth
  const [checking, setChecking] = useState(true)

  // Check auth on mount
  useEffect(() => {
    const doAuthCheck = async () => {
      await checkAuth()
      setChecking(false)
    }
    doAuthCheck()
  }, [])

  // Show loading while checking auth
  if (checking) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <p className="text-muted-foreground">Loading...</p>
      </div>
    )
  }

  // Redirect to login if not authenticated
  if (!user) {
    return <Navigate to="/login" replace />
  }

  return (
    <HomeLayout
      title="MakeReady"
      user={user}
      avatar={
        <Avatar>
          <AvatarImage
            src={user.picture || undefined}
            alt={user.name}
            referrerPolicy="no-referrer"
          />
          <AvatarFallback>{user.name.charAt(0).toUpperCase()}</AvatarFallback>
        </Avatar>
      }
      headerActions={
        <Button
          onClick={() => Application.domain.auth.logout()}
          variant="Destructive"
          size="Sm"
        >
          Logout
        </Button>
      }
      centerContent
    >
      <div className="text-center">
        <h2 className="text-3xl font-bold mb-4">Welcome, {user.name}!</h2>
        <p className="text-muted-foreground mb-8">
          You are successfully authenticated with Google.
        </p>

        {when(
          !!user.email,
          <p className="text-sm text-muted-foreground">
            Logged in as: {user.email}
          </p>
        )}
      </div>
    </HomeLayout>
  )
})

HomePage.displayName = 'HomePage'
