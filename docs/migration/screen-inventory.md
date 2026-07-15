# Screen Inventory

This document inventories the React screens that are reachable in the current application and highlights the migration-relevant behavior for each one.

## Summary

The app is a transformer-design workflow with authentication, design listing, calculation screens, fabrication/core views, and a small admin/profile area. The primary route group is protected by the private-route wrapper.

## Screen catalog

| Screen | Route | React component | Primary purpose |
| --- | --- | --- | --- |
| Login | / | Signin.js | Sign in with username/email and password |
| Sign up | /signUp | Signup.js | Register a new account and complete OTP validation |
| Forgot password | /forgotPassword | sendOtp/index.js | Request OTP and reset password |
| Home / design list | /home | page/home/Home.js | Browse saved transformer designs, create new ones, search, delete, logout |
| Two-winding designer | /2windings/:id | page/twoWinding/TwoWinding.js | Full two-winding calculation and form-driven design |
| Multi-winding designer | /multiwindings/:id | page/multiWinding/MultiWinding.js | Multi-winding calculation workspace |
| Fabrication | /fabrication/:id | page/fabrication/Fabrication.js | Fabrication parameters and 3D generation workflow |
| Core model | /core/:id | page/coreModel/CoreModel.js | Core geometry and blade/step configuration |
| Files / LOM / cost document | /files/:id | page/files/Files.js | Generate LOM/CCC-like output, manage material rates, export PDF |
| Profile | /profile | page/profile/profile.js | View/edit profile data |
| Users | /users | page/users/users.js | CRUD for user records |
| Socket demo | /socket | page/other/SocketChat.js | Minimal socket-based sample demo |
| LOM cost settings | /lomCost | page/lomCost/lomCost.js | Update rate/material settings |

## Detailed screen notes

### 1. Login
- React component: Signin.js
- Route: /
- APIs called:
  - POST /auth/signin via AuthSaga
  - POST /entity/v2/lomMaterial via entity fetch after sign-in
- Redux actions / reducers / sagas:
  - actions: signIn, fetchEntity, clearErrorMessage, signOut
  - reducer: auth reducer; entity reducer for lomMaterial
  - saga: AuthSaga, EntitySaga
- Form fields and validations:
  - Username/Email, Password
  - Validation: required fields, no spaces in username/email/password, minimum password length 6
- Dependent components:
  - CustomCard, InputContainer, ModalButton, Login.styles
- Loading / success / error states:
  - Loading: auth.isLoading
  - Success: isAuthenticated true; app redirects to /home
  - Error: errorMessage from auth reducer
- Desktop-specific behavior:
  - Keyboard Enter triggers sign-in
  - Uses password visibility toggle
  - Browser redirect handling for session expiry

### 2. Sign up
- React component: Signup.js
- Route: /signUp
- APIs called:
  - POST /auth/signup
  - POST /auth/sendEmailOtp (via sendOTP action)
- Redux actions / reducers / sagas:
  - actions: signUp, sendOTP, clearErrorMessage
  - reducer: auth reducer
  - saga: AuthSaga
- Form fields and validations:
  - Username, Password, Confirm Password, Email ID, OTP
  - Validation: email required and must contain @, username required, no whitespace, password minimum 6, confirm password matches, OTP required
- Dependent components:
  - CustomCard, InputContainer, ModalButton
- Loading / success / error states:
  - Loading: auth.isLoading
  - Success: signUpSucceeded true, redirect to login
  - Error: auth.errorMessage
- Desktop-specific behavior:
  - OTP request is handled inline; no desktop-only features beyond standard web form behavior

### 3. Forgot password
- React component: sendOtp/index.js
- Route: /forgotPassword
- APIs called:
  - POST /auth/sendForgotPasswordOtp
  - POST /auth/passwordResetByEmail or /auth/passwordResetByOtp (depending on flow)
- Redux actions / reducers / sagas:
  - actions: sendOTP, resetPassword, clearErrorMessage
  - reducer: auth reducer
  - saga: AuthSaga
- Form fields and validations:
  - Email, OTP, New Password
  - Validation: email required, OTP required, password minimum 6
- Dependent components:
  - CustomCard, ModalButton, password visibility toggle UI
- Loading / success / error states:
  - Loading: auth.isLoading
  - Success: sessionInfo set and/or passwordResetSucceeded true
  - Error: auth.errorMessage
- Desktop-specific behavior:
  - Same as web form flow; no explicit desktop-only logic

### 4. Home / design list
- React component: Home.js
- Route: /home
- APIs called:
  - POST /entity/v2/design/list through entityApi.list
  - POST /entity/v2/design/search through entityApi.search
  - POST /entity/v2/lomMaterial for new design options
  - POST /auth/logout
- Redux actions / reducers / sagas:
  - actions: fetchEntity, fetchSearchEntity, deleteEntity, clearCalc, generate3DCleared, resetCustomerData, signOut
  - reducers: entity reducer, calc reducer, file reducer, auth reducer
  - sagas: EntitySaga, CalcSaga, AuthSaga, FileSaga
- Form fields and validations:
  - Search input for design reference
  - Modal selection for design type (currently only 2-winding is exposed; multi-winding option is disabled by showMultiWdgOption = false)
  - No complex validation for the list screen itself
- Dependent components:
  - Layout, SearchInput, CheckedTable, Pagination, CustomModal, ConfirmationDialog, profile menu components
- Loading / success / error states:
  - Loading: entity.design.isLoading
  - Success: design data loaded and grid rendered
  - Error: design.isFailed; also logout errors are logged but do not block UI
- Desktop-specific behavior:
  - Uses a dark/light theme toggle persisted in localStorage
  - Profile/settings dropdowns and keyboard/mouse interactions are browser-based
  - Uses browser URL navigation for route selection

### 5. Two-winding designer
- React component: TwoWinding.js
- Route: /2windings/:id
- APIs called:
  - POST /calculate/2windings (or body-type variant if applicable) through CalcSaga
  - PUT /entity/design (or /entity/design/:id) to persist design state
- Redux actions / reducers / sagas:
  - actions: addCalc, clearCalc, addCalcFullfiled, addEntity
  - reducers: calc reducer (twoWindings slice), entity reducer (design)
  - saga: CalcSaga, EntitySaga
- Form fields and validations:
  - Large multi-section form with fields for:
    - transformer basics: kVA, voltage levels, winding types, vector group, frequency
    - core: core diameter, limb height, core material, flux density
    - windings: turns, current density, conductor size, insulation, parallel conductors
    - tank/oil: tank dimensions, oil capacity, losses, comments, locking attributes
  - Validation is mostly implicit in the UI and downstream calculations; no obvious client-side validator layer is present
- Dependent components:
  - Part1, Part2, Part3, CoilDimensionsTabs, Layout, custom inputs/components
- Loading / success / error states:
  - Loading: calc.twoWindings.isLoading
  - Success: calc.twoWindings.isFullfilled and persisted entity data available
  - Error: calc.twoWindings.isFailed
- Desktop-specific behavior:
  - Ctrl/Cmd + Enter triggers calculation from the browser window
  - Uses complex tabbed form UI and dark/light theming
  - Has hover/comment behaviour for certain form fields

### 6. Multi-winding designer
- React component: MultiWinding.js
- Route: /multiwindings/:id
- APIs called:
  - POST to the dedicated multi-winding calculator backend via MULTI_WDG_CALCULATOR_PATH
- Redux actions / reducers / sagas:
  - actions: addCalc, clearCalc
  - reducers: calc reducer (multiWindings slice)
  - saga: CalcSaga
- Form fields and validations:
  - Multi-step inputs split into Part1, Part2, Part3
  - Field groups include design basics, winding details, dimensions and cost inputs
  - Validation is minimal and mostly relies on the backend calculation response
- Dependent components:
  - Part1, Part2, Part3
- Loading / success / error states:
  - Loading: multiWindings.isLoading
  - Success: response mapped into UI state via response mapping utility
  - Error: multiWindings.isFailed
- Desktop-specific behavior:
  - Ctrl/Cmd + Enter triggers calculation
  - The route exists, but the UI currently hints that the workflow is still being built out

### 7. Fabrication
- React component: Fabrication.js
- Route: /fabrication/:id
- APIs called:
  - POST /calculate/fabrication (via addCalc action)
  - POST /cad/run-3d-generation for 3D generation
  - GET /models/:designId.glb for loading the generated 3D model
  - POST /entity/drawingsStatus to track CAD status
- Redux actions / reducers / sagas:
  - actions: addCalc, generate3DRequest, load3DRequest, fetchEntity, addEntity, deleteEntity, generate3DCleared
  - reducers: calc reducer (fabrication, generate3d), entity reducer (drawingsStatus)
  - sagas: CalcSaga, EntitySaga
- Form fields and validations:
  - Large fabrication form including tank, radiator, valves, bushings, cable boxes, lifting lugs, terminal accessories, and other mechanical parameters
  - The form is pre-populated from twoWindings data and core results
  - Validation is largely implicit and backend-driven
- Dependent components:
  - Part1, Part2, Part3, AccessoriesTabs, OtherTabs, accessories content subcomponents, socket-based CAD status watcher
- Loading / success / error states:
  - Loading: fabrication.isLoading, generate3d.isLoading
  - Success: fabrication data and drawings status update; 3D blob eventually available
  - Error: fabrication.isFailed or generate3d generation failure
- Desktop-specific behavior:
  - Uses socket.io to listen for CAD server updates
  - Ctrl/Cmd + Enter triggers calculation
  - 3D generation workflow is browser-driven and stateful

### 8. Core model
- React component: CoreModel.js
- Route: /core/:id
- APIs called:
  - POST /calculate/core (via addCalc)
- Redux actions / reducers / sagas:
  - actions: addCalc
  - reducers: calc reducer (core slice)
  - saga: CalcSaga
- Form fields and validations:
  - Core diameter, minimum step width, number of steps, fixture step width, blade type
  - Users can edit step rows and save core stack changes
- Dependent components:
  - CircularDiagram, CustomInput, PrintPreview, CoreModel.css
- Loading / success / error states:
  - Loading: core.isLoading
  - Success: core data is fetched and displayed in the diagram and metrics
  - Error: core.isFailed
- Desktop-specific behavior:
  - Displays a visual diagram and supports step-level editing
  - Ctrl/Cmd + Enter triggers the core calculation

### 9. Files / LOM / cost document
- React component: Files.js
- Route: /files/:id
- APIs called:
  - POST /files/lom through FileSaga
  - POST /entity/v2/lomMaterial to fetch rate/material data
  - PUT /entity/... for customer and design-related persistence
- Redux actions / reducers / sagas:
  - actions: fetchFile, addDataToLom, deleteDataFromLom, addCustomer, fetchEntity, addEntity
  - reducers: file reducer, entity reducer
  - saga: FileSaga, EntitySaga
- Form fields and validations:
  - Material rows, quantity/rate overrides, customer details, LOM rows, PDF export fields
  - Validation is mostly manual and UI-driven; no centralized validation schema is obvious
- Dependent components:
  - Table, PDF generation utilities, custom accordion UI, images/assets
- Loading / success / error states:
  - Loading: lom.isLoading, customer.isLoading
  - Success: lom data generated and displayed in tables/PDF
  - Error: lom.isFailed or file generation failure
- Desktop-specific behavior:
  - PDF generation is browser-based and uses jsPDF/autotable
  - The page appears to be a document/reporting surface, not a desktop app feature

### 10. Profile
- React component: profile.js
- Route: /profile
- APIs called:
  - POST /entity/v2/profile/list
  - PUT /entity/profile/:id for updates
- Redux actions / reducers / sagas:
  - actions: fetchEntity, addEntity, updateEntity
  - reducers: entity reducer
  - saga: EntitySaga
- Form fields and validations:
  - Primary contact fields: first name, last name, company name, designation, email, phone
  - Address tab fields: state, city, address, pincode
- Dependent components:
  - Address, BankDetails, NavTabs, ProfileLayout
- Loading / success / error states:
  - Loading: profile.isLoading
  - Success: profile data populated and edit mode transitions cleanly
  - Error: entity failure is not shown as a prominent state in this screen
- Desktop-specific behavior:
  - Standard tabbed form with editable cards

### 11. Users
- React component: users.js
- Route: /users
- APIs called:
  - POST /entity/v2/users/list
  - PUT /entity/users/:id for updates
  - PUT /entity/users for create
  - DELETE /entity/users/:id for delete
- Redux actions / reducers / sagas:
  - actions: fetchEntity, addEntity, deleteEntity, updateEntity
  - reducers: entity reducer
  - saga: EntitySaga
- Form fields and validations:
  - Name, Email
  - Validation: checks for empty fields before add
- Dependent components:
  - ConfirmationDialog, ProfileLayout, CustomInput, FilledBtn
- Loading / success / error states:
  - Loading: users.isLoading
  - Success: rows render after CRUD operations
  - Error: not prominently surfaced in UI
- Desktop-specific behavior:
  - Simple CRUD table; no special desktop-only logic

### 12. Socket demo
- React component: SocketChat.js
- Route: /socket
- APIs called:
  - None via the Redux layer; it directly uses socket.io-client to localhost:5000
- Redux actions / reducers / sagas:
  - None
- Form fields and validations:
  - Message input; no validation beyond trimming empty messages
- Dependent components:
  - None beyond the local component state
- Loading / success / error states:
  - No formal loading state; messages update over time
  - Error handling is minimal
- Desktop-specific behavior:
  - This looks like a utility/demo screen rather than a production workflow

### 13. LOM cost settings
- React component: lomCost/lomCost.js
- Route: /lomCost
- APIs called:
  - Uses the entity layer for material-rate persistence, likely through general entity actions
- Redux actions / reducers / sagas:
  - actions: fetchEntity, addEntity, updateEntity
  - reducers: entity reducer
  - saga: EntitySaga
- Form fields and validations:
  - Rate input table for materials and equivalents
- Dependent components:
  - Likely uses shared layout/components and rate tables
- Loading / success / error states:
  - Uses entity loading state for material data
- Desktop-specific behavior:
  - Browser-based settings page; no dedicated desktop-only behavior was observed in the current code

## Unclear or duplicated behavior flags

- The multi-winding route exists but the UI is still marked as a new workspace and the option to open it is disabled in the home page.
- The app uses several nearly identical patterns for entity CRUD and calculation flows; there is duplication between the entity actions and the calc actions that may need consolidation in a Flutter migration.
- The form validation is inconsistent: some screens validate in component code, while others rely on backend response and reducer state.
- There is some apparent duplication between the two-winding and fabrication/core calculation flows in how they persist design IDs and entity references.
- The socket demo and CAD workflow both use network-driven state but are not integrated through a single status model.
- The route /socket appears to be a development/demo feature rather than a core user journey.
