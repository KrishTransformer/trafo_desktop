# Redux State Map

The application uses Redux Toolkit with redux-saga and a small set of slices. This document summarizes the state structure and how it maps to the UI screens.

## Store structure

The store is configured in src/app/store.js with the following reducers:

- entity
- auth
- config
- calc
- lom (file-related state)

## Slice map

### 1. auth

State path: auth

Purpose: authentication flow and session state.

Key fields:
- auth.isLoading
- auth.isAuthenticated
- auth.errorMessage
- auth.sessionInfo
- auth.phoneNumber
- auth.name
- auth.entityId
- auth.passwordResetSucceeded
- auth.signUpSucceeded
- auth.roles

Triggered by:
- SIGNIN_REQUESTED / SIGNIN_FULLFILLED / SIGNIN_FAILED
- SIGNUP_REQUESTED / SIGNUP_FULLFILLED / SIGNUP_FAILED
- SENDOTP_REQUESTED / SENDOTP_FULLFILLED / SENDOTP_FAILED
- RESETPASSWORD_REQUESTED / RESETPASSWORD_FULLFILLED / RESETPASSWORD_FAILED
- SIGNOUT / CLEAR_ERROR_MESSAGE

Used by:
- Login, SignUp, Forgot Password, Home profile/logout

### 2. entity

State path: entity

Purpose: generic CRUD state for domain entities.

Key entity buckets:
- design
- drawingsStatus
- lomMaterial
- users
- profile

Each entity has:
- isLoading
- isFullfilled
- isAddCompleted
- isFailed
- data

Used by:
- Home (design list), Fabrication (drawingsStatus), Files (lomMaterial), Profile, Users

### 3. config

State path: config

Purpose: tenant/config information.

Key fields:
- config.isLoading
- config.isFullfilled
- config.isFailed
- config.data

Used by:
- Login/Signup/Forgot Password to read tenant branding info

### 4. calc

State path: calc

Purpose: calculation state for design workflows.

Key sub-states:
- twoWindings
- multiWindings
- fabrication
- core
- generate3d

Typical fields:
- isLoading, isFullfilled, isFailed, data, metadata

Used by:
- TwoWinding, MultiWinding, Fabrication, CoreModel

### 5. lom / file state

State path: lom

Purpose: LOM/material generation plus customer-related temporary state.

Key fields:
- lom.data
- lom.isLoading
- lom.isFullfilled
- lom.isFailed
- lom.error
- customer.data

Used by:
- Files page

## Saga-driven side effects

The Redux slice state is populated by sagas:

- AuthSaga handles login/signup/password reset
- EntitySaga handles generic CRUD and entity search/list operations
- CalcSaga handles calculation requests and 3D generation
- FileSaga generates LOM payloads and calls file services
- ConfigSaga fetches config data

## Migration implications

- The state model is fairly domain-centric and can be mirrored in Flutter using a structured state container or Riverpod/Bloc.
- The generic entity reducer is a strong candidate for a typed repository layer rather than bespoke screen-specific state.
- The calc slice is large and deeply nested; the Flutter rewrite should model it as domain objects rather than raw JSON maps where possible.
