# Route Map

This file summarizes the routing structure and the user journey implied by the current React router setup.

## Router configuration

The app uses React Router v6 with BrowserRouter. Routes are declared in App.js and protected by a PrivateRoutes wrapper.

## Public routes

| Route | Component | Notes |
| --- | --- | --- |
| / | Login | Entry page for authentication |
| /signUp | SignUp | Registration flow |
| /forgotPassword | RequestOtp | Password reset flow |
| * | Login | Fallback route |

## Protected routes

| Route | Component | Access conditions |
| --- | --- | --- |
| /home | Home | Requires auth token or Redux auth state |
| /2windings/:id | TwoWinding | Protected |
| /multiwindings/:id | MultiWinding | Protected |
| /fabrication/:id | Fabrication | Protected |
| /files/:id | Files | Protected |
| /core/:id | CoreModel | Protected |
| /socket | SocketChat | Protected |
| /profile | Profile | Protected |
| /users | Users | Protected |
| /lomCost | LomCost | Protected |

## Navigation patterns

- The login flow redirects to /home after authentication.
- The home screen launches the design workflow by navigating to /2windings/new or /multiwindings/new.
- The design workflow screens are parameterized by a design id, typically stored in the route path or in the design state.
- Files, fabrication, and core pages are all accessed after a design has been created or loaded.

## Migration notes

- The route structure is simple and shallow, which is favorable for Flutter route mapping.
- The protected-route model can be mirrored as a guarded shell in Flutter.
- Some routes such as /socket appear to be demo/debug pages and may be excluded or simplified in a migration scope.
- Route parameter id is used as a design identifier across several screens; this should be treated as a first-class domain concept in the Flutter app.
