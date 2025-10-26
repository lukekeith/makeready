import { observable, computed, action, makeObservable } from 'mobx'
import { Store } from '../Store'
import { ApplicationStore } from '../ApplicationStore'

export class LoginUI extends Store {
  @observable email = ''
  @observable isLoading = false
  @observable error: string | null = null

  constructor(application: ApplicationStore) {
    super(application)
    makeObservable(this)
  }

  @action
  setEmail = (email: string) => {
    this.email = email
    this.error = null // Clear error when user types
  }

  @action
  setLoading = (loading: boolean) => {
    this.isLoading = loading
  }

  @action
  setError = (error: string | null) => {
    this.error = error
  }

  @action
  handleEmailSubmit = async () => {
    if (!this.email) {
      this.setError('Email is required')
      return
    }

    if (!this.isValidEmail(this.email)) {
      this.setError('Please enter a valid email address')
      return
    }

    this.setLoading(true)
    this.setError(null)

    try {
      // TODO: Replace with actual authentication API call
      // await this.application.domain.auth.loginWithEmail(this.email)
      console.log('Signing in with email:', this.email)

      // Simulate API call
      await new Promise((resolve) => setTimeout(resolve, 2000))

      // TODO: Navigate to next step (e.g., phone verification, dashboard)
    } catch (error) {
      this.setError(error instanceof Error ? error.message : 'Failed to sign in')
    } finally {
      this.setLoading(false)
    }
  }

  @action
  handleSocialLogin = async (provider: 'google' | 'github') => {
    this.setLoading(true)
    this.setError(null)

    try {
      if (provider === 'google') {
        // Redirect to Google OAuth
        this.application.domain.auth.loginWithGoogle()
      } else {
        this.setError('GitHub login not implemented yet')
        this.setLoading(false)
      }
    } catch (error) {
      this.setError(
        error instanceof Error ? error.message : `Failed to sign in with ${provider}`
      )
      this.setLoading(false)
    }
  }

  @action
  clearError = () => {
    this.error = null
  }

  @action
  reset = () => {
    this.email = ''
    this.isLoading = false
    this.error = null
  }

  private isValidEmail(email: string): boolean {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    return emailRegex.test(email)
  }

  // Computed props for components
  @computed
  get emailInputProps() {
    return {
      id: 'email',
      type: 'email' as const,
      placeholder: 'name@example.com',
      value: this.email,
      onChange: (e: React.ChangeEvent<HTMLInputElement>) => this.setEmail(e.target.value),
      disabled: this.isLoading,
      required: true,
    }
  }

  @computed
  get submitButtonProps() {
    return {
      type: 'submit' as const,
      disabled: this.isLoading || !this.email,
      className: 'w-full',
    }
  }

  @computed
  get submitButtonText() {
    return this.isLoading ? 'Signing in...' : 'Sign In with Email'
  }
}
