import { Store } from './Store';
import { ApplicationStore } from './ApplicationStore';
import { AuthDomain } from './domain/auth.domain';
export declare class DomainStore extends Store {
    auth: AuthDomain;
    constructor(application: ApplicationStore);
}
