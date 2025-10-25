import { observable, makeObservable, computed, action } from 'mobx'
import { Store } from './Store'
import { ApplicationStore } from './ApplicationStore'

export class SessionStore extends Store {
  @observable token?: string
  @observable userId?: string

  constructor(application: ApplicationStore) {
    super(application)
    makeObservable(this)
  }

  @computed
  get isAuthenticated(): boolean {
    return !!this.token && !!this.userId
  }

  @action
  setAuth(token: string, userId: string) {
    this.token = token
    this.userId = userId
  }

  @action
  clearAuth() {
    this.token = undefined
    this.userId = undefined
  }
}
