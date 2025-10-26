import { observable, makeObservable } from 'mobx'
import { Store } from './Store'
import { ApplicationStore } from './ApplicationStore'
import { LoginUI } from './ui/login.ui'

export class UIStore extends Store {
  @observable login: LoginUI

  constructor(application: ApplicationStore) {
    super(application)
    this.login = new LoginUI(application)
    makeObservable(this)
  }
}
