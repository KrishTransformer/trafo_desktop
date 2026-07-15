# Authentication Flow

This document records the authentication and session flow in the current React application.

## Overview

Authentication is handled through the auth reducer/saga layer and a shared Axios interceptor. The app uses a simple token-based session model with redirect handling for expired sessions.

## Flow

1. The user enters username/email and password on the login screen.
2. The Login component dispatches signIn(username, password).
3. The AuthSaga sends the request to /auth/signin.
4. If authentication succeeds:
   - signInFullfiled stores tokens and user metadata
   - the app fetches the lomMaterial entity list
   - the Redux auth state becomes authenticated and the app redirects to /home
5. If authentication fails:
   - the auth reducer stores an error message and the UI renders an alert
6. Logout calls /auth/logout if a token exists, then clears local auth state and redirects to /

## Key form validations

- Login validation requires both fields.
- Username/email and password cannot contain whitespace.
- Password must be at least 6 characters.
- Sign-up validation adds email format checks, password confirmation, and OTP requirement.
- Forgot password validation requires an email, OTP, and a new password.

## Session behavior

- The PrivateRoutes component allows access to protected routes if either Redux auth is true or a token exists.
- The Axios interceptor checks for 401/403 responses and redirects the user to login with a redirect message.
- Auth tokens are stored through the authToken helper module.

## Migration notes

- The current auth model is straightforward and can be mapped to Flutter authentication flows with a token/session provider and a protected shell.
- The sign-up and password reset flows are separate but share the same auth reducer and saga layer.
- The login screen also uses tenant/config data while rendering; this should be considered part of the bootstrapping experience in a Flutter migration.
