import React, { useEffect } from 'react'
import { observer } from 'mobx-react'
import { Navigate } from 'react-router-dom'
import { Application } from '@/store/ApplicationStore'
import { Avatar, AvatarImage, AvatarFallback } from 'ui'
import { when } from 'util'

export const AdminPage = observer(() => {
  const { user } = Application.session
  const { isLoading, checkAuth } = Application.domain.auth

  // Check auth on mount
  useEffect(() => {
    checkAuth()
  }, [])

  // Show loading while checking auth
  if (isLoading) {
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
    <div className="min-h-screen bg-background">
      {/* Header with avatar */}
      <header className="border-b border-border">
        <div className="container flex items-center justify-between h-16 px-4">
          <h1 className="text-xl font-semibold">MakeReady Admin</h1>

          <div className="flex items-center gap-4">
            <span className="text-sm text-muted-foreground hidden sm:block">
              {user.name}
            </span>
            <Avatar>
              <AvatarImage src={user.picture || undefined} alt={user.name} />
              <AvatarFallback>{user.name.charAt(0).toUpperCase()}</AvatarFallback>
            </Avatar>
          </div>
        </div>
      </header>

      {/* Main content */}
      <main className="container px-4 py-8">
        <div className="flex flex-col items-center justify-center min-h-[60vh]">
          <h2 className="text-3xl font-bold mb-4">Welcome, {user.name}!</h2>
          <p className="text-muted-foreground mb-8">
            You are successfully authenticated with Google.
          </p>

          {when(
            user.email,
            <p className="text-sm text-muted-foreground">
              Logged in as: {user.email}
            </p>
          )}

          <button
            onClick={() => Application.domain.auth.logout()}
            className="mt-8 px-4 py-2 bg-destructive text-destructive-foreground rounded-md hover:bg-destructive/90 transition-colors"
          >
            Logout
          </button>
        </div>
      </main>
    </div>
  )
})

AdminPage.displayName = 'AdminPage'
