import { observable, makeObservable } from 'mobx'
import { Store } from './Store'
import { ApplicationStore } from './ApplicationStore'

export class UIStore extends Store {
  // Add UI stores here as the app grows
  // Example:
  // @observable navigation = new NavigationUIStore(this.application)

  constructor(application: ApplicationStore) {
    super(application)
    makeObservable(this)
  }
}
