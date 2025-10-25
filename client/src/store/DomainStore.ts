import { observable, makeObservable } from 'mobx'
import { Store } from './Store'
import { ApplicationStore } from './ApplicationStore'

export class DomainStore extends Store {
  // Add domain stores here as the app grows
  // Example:
  // @observable users = new UsersStore(this.application)

  constructor(application: ApplicationStore) {
    super(application)
    makeObservable(this)
  }
}
