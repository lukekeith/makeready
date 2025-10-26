import { observable, makeObservable, computed, action } from 'mobx'
import { Store } from './Store'
import { ApplicationStore } from './ApplicationStore'
import { User } from './domain/auth.domain'

export class SessionStore extends Store {
  @observable user: User | null = null

  constructor(application: ApplicationStore) {
    super(application)
    makeObservable(this)
  }

  @computed
  get isAuthenticated(): boolean {
    return !!this.user
  }

  @action
  setUser(user: User | null) {
    this.user = user
  }

  @action
  clearAuth() {
    this.user = null
  }
}
