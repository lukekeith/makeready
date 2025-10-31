import { Store } from './Store';
import { ApplicationStore } from './ApplicationStore';
import { LoginUI } from './ui/login.ui';
export declare class UIStore extends Store {
    login: LoginUI;
    constructor(application: ApplicationStore);
}
