import React, { useEffect, useState } from 'react'
import { observer } from 'mobx-react'
import { Navigate } from 'react-router-dom'
import { Application } from '@/store/ApplicationStore'
import { Avatar, AvatarImage, AvatarFallback } from 'ui'

export const HomePage = observer(() => {
  const { user } = Application.session
  const { checkAuth } = Application.domain.auth
  const [checking, setChecking] = useState(true)

  // Check auth on mount
  useEffect(() => {
    const doAuthCheck = async () => {
      console.log('🔍 HomePage: Checking auth...')
      const isAuth = await checkAuth()
      console.log('🔍 HomePage: Auth check complete, isAuth:', isAuth, 'user:', Application.session.user)
      setChecking(false)
    }
    doAuthCheck()
  }, [])

  // Show loading while checking auth
  if (checking) {
    console.log('🔍 HomePage: Still checking auth...')
    return (
      <div className="flex items-center justify-center min-h-screen">
        <p className="text-muted-foreground">Loading...</p>
      </div>
    )
  }

  // Redirect to login if not authenticated
  if (!user) {
    console.log('❌ HomePage: No user, redirecting to login')
    return <Navigate to="/login" replace />
  }

  console.log('✅ HomePage: User authenticated, showing page')
  return (
    <div className="min-h-screen bg-background">
      {/* Header with avatar in top right */}
      <header className="absolute top-0 right-0 p-4">
        <Avatar>
          <AvatarImage src={user.picture || undefined} alt={user.name} />
          <AvatarFallback>{user.name.charAt(0).toUpperCase()}</AvatarFallback>
        </Avatar>
      </header>
    </div>
  )
})

HomePage.displayName = 'HomePage'
