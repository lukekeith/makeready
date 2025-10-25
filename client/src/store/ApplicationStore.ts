import { observable, makeObservable, action } from 'mobx'
import { DomainStore } from './DomainStore'
import { SessionStore } from './SessionStore'
import { UIStore } from './UIStore'

export class ApplicationStore {
  @observable domain: DomainStore
  @observable session: SessionStore
  @observable ui: UIStore

  constructor() {
    makeObservable(this)
    this.domain = new DomainStore(this)
    this.session = new SessionStore(this)
    this.ui = new UIStore(this)
  }

  @action
  clear() {
    this.domain = new DomainStore(this)
    this.session = new SessionStore(this)
  }
}

// Singleton instance
export const Application = new ApplicationStore()
