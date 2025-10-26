import { observable, action, makeObservable, runInAction } from 'mobx'
import { Store } from '../Store'
import { ApplicationStore } from '../ApplicationStore'

export interface User {
  id: string
  googleId: string
  email: string
  name: string
  picture: string | null
  createdAt: string
  updatedAt: string
}

export class AuthDomain extends Store {
  @observable user: User | null = null
  @observable isLoading = false
  @observable error: string | null = null

  constructor(application: ApplicationStore) {
    super(application)
    makeObservable(this)
  }

  @action
  setUser = (user: User | null) => {
    this.user = user
    // Update session store
    this.application.session.setUser(user)
  }

  @action
  setLoading = (loading: boolean) => {
    this.isLoading = loading
  }

  @action
  setError = (error: string | null) => {
    this.error = error
  }

  /**
   * Initiate Google OAuth login
   * Redirects to server auth endpoint
   */
  @action
  loginWithGoogle = () => {
    window.location.href = 'http://localhost:3001/auth/google'
  }

  /**
   * Check if user is authenticated
   * Calls /auth/me endpoint
   */
  @action
  checkAuth = async () => {
    this.setLoading(true)
    this.setError(null)

    try {
      const response = await fetch('http://localhost:3001/auth/me', {
        credentials: 'include', // Important: sends cookies
      })

      if (response.ok) {
        const data = await response.json()
        runInAction(() => {
          this.setUser(data.user)
        })
        return true
      } else {
        runInAction(() => {
          this.setUser(null)
        })
        return false
      }
    } catch (error) {
      runInAction(() => {
        this.setError(error instanceof Error ? error.message : 'Failed to check auth')
        this.setUser(null)
      })
      return false
    } finally {
      runInAction(() => {
        this.setLoading(false)
      })
    }
  }

  /**
   * Logout user
   */
  @action
  logout = async () => {
    this.setLoading(true)
    this.setError(null)

    try {
      const response = await fetch('http://localhost:3001/auth/logout', {
        method: 'POST',
        credentials: 'include',
      })

      if (response.ok) {
        runInAction(() => {
          this.setUser(null)
        })
        // Redirect to login
        window.location.href = '/login'
      } else {
        throw new Error('Logout failed')
      }
    } catch (error) {
      runInAction(() => {
        this.setError(error instanceof Error ? error.message : 'Failed to logout')
      })
    } finally {
      runInAction(() => {
        this.setLoading(false)
      })
    }
  }

  /**
   * Clear error
   */
  @action
  clearError = () => {
    this.error = null
  }
}
