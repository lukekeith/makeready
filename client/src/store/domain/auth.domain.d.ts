import { Store } from '../Store';
import { ApplicationStore } from '../ApplicationStore';
export interface User {
    id: string;
    googleId: string;
    email: string;
    name: string;
    picture: string | null;
    createdAt: string;
    updatedAt: string;
}
export declare class AuthDomain extends Store {
    user: User | null;
    isLoading: boolean;
    error: string | null;
    constructor(application: ApplicationStore);
    setUser: (user: User | null) => void;
    setLoading: (loading: boolean) => void;
    setError: (error: string | null) => void;
    /**
     * Initiate Google OAuth login
     * Redirects to server auth endpoint
     */
    loginWithGoogle: () => void;
    /**
     * Check if user is authenticated
     * Calls /auth/me endpoint
     */
    checkAuth: () => Promise<boolean>;
    /**
     * Logout user
     */
    logout: () => Promise<void>;
    /**
     * Clear error
     */
    clearError: () => void;
}
