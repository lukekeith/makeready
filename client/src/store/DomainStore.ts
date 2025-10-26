import { observable, makeObservable } from 'mobx'
import { Store } from './Store'
import { ApplicationStore } from './ApplicationStore'
import { AuthDomain } from './domain/auth.domain'

export class DomainStore extends Store {
  @observable auth: AuthDomain

  constructor(application: ApplicationStore) {
    super(application)
    this.auth = new AuthDomain(application)
    makeObservable(this)
  }
}
