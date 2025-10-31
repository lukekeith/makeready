import { Store } from './Store';
import { ApplicationStore } from './ApplicationStore';
import { User } from './domain/auth.domain';
export declare class SessionStore extends Store {
    user: User | null;
    constructor(application: ApplicationStore);
    get isAuthenticated(): boolean;
    setUser(user: User | null): void;
    clearAuth(): void;
}
