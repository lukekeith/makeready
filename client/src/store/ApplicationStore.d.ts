import { DomainStore } from './DomainStore';
import { SessionStore } from './SessionStore';
import { UIStore } from './UIStore';
export declare class ApplicationStore {
    domain: DomainStore;
    session: SessionStore;
    ui: UIStore;
    constructor();
    clear(): void;
}
export declare const Application: ApplicationStore;
