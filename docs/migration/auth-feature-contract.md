# Authentication Feature Contract

This document locks the migration contract for the first complete Flutter feature slice: authentication and guarded app entry.

Source references in the React app:
- `D:\krish_trafo\tf-web\src\App.js`
- `D:\krish_trafo\tf-web\src\components\privateRoute\PrivateRoute.js`
- `D:\krish_trafo\tf-web\src\components\signin\Signin.js`
- `D:\krish_trafo\tf-web\src\components\signup\Signup.js`
- `D:\krish_trafo\tf-web\src\components\sendOtp\index.js`
- `D:\krish_trafo\tf-web\src\sagas\AuthSaga.js`
- `D:\krish_trafo\tf-web\src\reducers\AuthReducer.js`
- `D:\krish_trafo\tf-web\src\actions\AuthActions.js`
- `D:\krish_trafo\tf-web\src\api\index.js`
- `D:\krish_trafo\tf-web\src\api\authToken.js`
- `D:\krish_trafo\tf-web\src\api\Cookies.js`
- `D:\krish_trafo\tf-web\src\sagas\ConfigSaga.js`

## Scope

The first Flutter feature slice should include:
- sign in
- sign up
- forgot password
- token persistence
- session expiry redirect
- guarded routing
- minimal config bootstrap needed by auth screens

It should not include business screens yet.

## Route contract

Public routes in React:
- `/` -> sign in
- `/signUp` -> sign up
- `/forgotPassword` -> forgot password

Protected routes in React:
- everything under `PrivateRoutes`

Guard rule in React:
- allow protected route if Redux `auth.isAuthenticated` is `true`
- or if `getIdToken()` returns a non-empty token from session storage

Flutter parity rule:
- protected routes must unlock when a valid stored token exists, even before a fresh sign-in action in the current session
- unauthenticated access to protected routes must redirect to sign in

## Token and session contract

React token storage:
- `idToken` stored in session storage
- `refreshToken` optionally stored in session storage

React request behavior:
- bearer token is added automatically unless request header `X-Skip-Auth: true` is present

React expiry behavior:
- on `401` or `403`, if request had bearer auth:
  - clear auth tokens
  - store redirect message `Session expired. Please log in again.`
  - redirect to `/`

Flutter parity rule:
- keep automatic bearer token attachment
- clear secure storage on authenticated `401/403`
- redirect user to sign in
- show the same redirect message on next sign-in render

## API contract

Service used:
- `COMMON_SERVICE`

### 1. Sign in

Endpoint:
- `POST /auth/signin`

Request body fields observed in React:
- `usernameOrEmail`
- `password`
- plus exactly one of:
  - `email`
  - `username`

Request construction rule:
- if login input contains `@`, send `email`
- otherwise send `username`

Current React implementation also builds a Basic auth header from:
- `usernameOrEmail:password`

Flutter guidance:
- preserve request body exactly
- keep the Basic auth header only if backend still requires it for compatibility
- do not invent extra fields

Success fields definitely used by React:
- `idToken`
- `refreshToken` optional
- `roles`
- `entityId`
- `email`

Additional derived data:
- JWT payload from `idToken` is parsed for `name`

Post-success behavior:
- persist tokens
- mark session authenticated
- fetch `lomMaterial`
- redirect to `/home`

### 2. Sign up

Endpoint:
- `POST /auth/signup`

Request body fields observed in React:
- `username`
- `password`
- `email`
- `otp`

Success behavior:
- no response fields are required by the current UI
- redirect to `/` with message `Sign Up succeeded. Please sign in.`

### 3. Send OTP for sign up

Endpoint:
- `POST /auth/sendEmailOtp`

Request body fields observed in React:
- `email`

Success fields used by React:
- `sessionInfo` if present
- otherwise any truthy success is treated as enough to continue

UI behavior:
- sign-up screen shows `OTP was requested successfully. You can continue signup.`

### 4. Send OTP for forgot password

Endpoint:
- `POST /auth/sendForgotPasswordOtp`

Request body fields observed in React:
- `email`

Success fields used by React:
- `sessionInfo` if present

UI behavior:
- forgot-password screen shows `OTP sent to the registered email`
- OTP and new-password inputs appear only after `sessionInfo` becomes truthy

### 5. Reset password by email

Endpoint:
- `POST /auth/passwordResetByEmail`

Request body fields observed in React:
- `email`
- `otp`
- `newPassword`

Success behavior:
- redirect to `/` with message `Password reset succeeded. Please sign in.`

### 6. Logout

Endpoint:
- `POST /auth/logout`

Request body observed in React:
- empty object

Behavior:
- logout API failure does not block local sign-out
- local sign-out still clears tokens and redirects to `/`

## Validation contract

### Sign in

Client validations in React:
- username/email required
- password required
- no whitespace in username/email
- no whitespace in password
- password minimum length `6`

Keyboard behavior:
- Enter submits

### Sign up

Client validations in React:
- email required
- email must contain `@`
- username required
- no whitespace in username
- no whitespace in email
- no whitespace in password
- no whitespace in confirm password
- no whitespace in otp
- password minimum length `6`
- confirm password must match
- otp required

### Forgot password

Client validations in React:
- email required before sending OTP
- otp required before reset
- password minimum length `6`

## Error-message contract

React normalizes sign-in failures to:
- `Please register` for `EMAIL_NOT_FOUND` or `USER_NOT_FOUND`
- `Invalid Username or Password` for `401`, `INVALID_PASSWORD`, `INVALID_CREDENTIAL`, `BAD_CREDENTIAL`, `UNAUTHORIZED`

React normalizes sign-up failures to:
- `Email is already registered. Please sign in.`
- `Username is already taken.`
- `Invalid OTP. Please try again.`
- `OTP expired. Please request a new OTP.`
- `Please enter a valid email address.`

Flutter parity rule:
- preserve these user-facing strings

## Config bootstrap contract

Endpoint:
- `GET /config`

Success field definitely used by React auth screens:
- `tenantName`

Observed gap in React:
- `fetchConfig` is imported into `Signin.js`, but I could not find an actual dispatch site for it in the checked codebase
- sign-up and forgot-password screens read config state for `tenantName`

Flutter migration rule:
- explicitly bootstrap `/config` before or during auth screen load
- only rely on fields proven in code, currently `tenantName`

## Screen behavior contract

### Sign in screen
- shows inline alerts for error and redirect message
- password visibility toggle
- forgot-password link
- sign-up link
- loading spinner inside submit button

### Sign up screen
- inline `Get OTP` action next to email field
- password and confirm-password visibility toggles
- loading spinner inside submit button
- link back to sign in

### Forgot password screen
- step 1: email + `Send OTP`
- step 2: once OTP request succeeds, show OTP and new-password fields
- password visibility toggle
- loading spinner inside action buttons

## Flutter implementation checklist for Task 2

When we implement the auth feature slice, it should include:
- typed auth request models
- typed config model for `tenantName`
- `AuthRepository`
- `ConfigRepository`
- auth application controller/state
- secure token read/write/clear
- guarded router redirect logic
- session-expiry redirect message persistence
- sign in screen
- sign up screen
- forgot password screen
- tests for:
  - request payloads
  - token persistence
  - route guard behavior
  - error mapping
  - screen validation and transitions

## Known open questions

- Whether `/auth/signin` still requires the Basic auth header in addition to the JSON body. The React app sends both. We should preserve that unless a verified backend test proves it is unnecessary.
- Whether `/config` returns more fields worth modeling. Only `tenantName` is currently proven by the checked auth screens.
