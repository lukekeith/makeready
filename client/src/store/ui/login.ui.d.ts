import { Store } from '../Store';
import { ApplicationStore } from '../ApplicationStore';
export declare class LoginUI extends Store {
    email: string;
    isLoading: boolean;
    error: string | null;
    constructor(application: ApplicationStore);
    setEmail: (email: string) => void;
    setLoading: (loading: boolean) => void;
    setError: (error: string | null) => void;
    handleEmailSubmit: () => Promise<void>;
    handleSocialLogin: (provider: "google" | "github") => Promise<void>;
    clearError: () => void;
    reset: () => void;
    private isValidEmail;
    get emailInputProps(): {
        id: string;
        type: "email";
        placeholder: string;
        value: string;
        onChange: (e: React.ChangeEvent<HTMLInputElement>) => void;
        disabled: boolean;
        required: boolean;
    };
    get submitButtonProps(): {
        type: "submit";
        disabled: boolean;
        className: string;
    };
    get submitButtonText(): "Signing in..." | "Sign In with Email";
}
