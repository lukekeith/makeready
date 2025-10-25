import { DomainStore } from './DomainStore'
import { SessionStore } from './SessionStore'
import { UIStore } from './UIStore'

export interface IApplicationStore {
  domain: DomainStore
  session: SessionStore
  ui: UIStore
}

export class Store {
  application: IApplicationStore

  constructor(app: IApplicationStore) {
    this.application = app
  }
}
