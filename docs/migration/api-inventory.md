# API Inventory

This document inventories the external API endpoints used by the React app and the layer that calls them.

## Service architecture

The app uses a thin API layer in src/api/index.js with multiple service configurations:

- COMMON_SERVICE: authentication, entity CRUD, config, and shared business data
- CORE_SERVICE: file/LOM-related operations
- CAD_SERVICE: 3D generation and CAD status
- MULTI_WDG_SERVICE: multi-winding calculation backend
- STORAGE_SERVICE: model file loading

## Endpoint inventory

| Category | Method | Endpoint | Source | Purpose |
| --- | --- | --- | --- | --- |
| Auth | POST | /auth/signin | AuthSaga | User login |
| Auth | POST | /auth/signup | AuthSaga | User registration |
| Auth | POST | /auth/sendForgotPasswordOtp | AuthSaga | Send OTP for password reset |
| Auth | POST | /auth/sendEmailOtp | AuthSaga | Send OTP during sign-up |
| Auth | POST | /auth/passwordResetByEmail | AuthSaga | Reset password by email + OTP |
| Auth | POST | /auth/passwordResetByOtp | AuthSaga | Reset password by OTP |
| Auth | POST | /auth/logout | Home.js | End session |
| Config | GET | /config | ConfigSaga | Fetch tenant/config information |
| Entity | POST | /entity/v2/:entityName | EntitySaga | List entities |
| Entity | POST | /entity/v2/:entityName/search | EntitySaga | Search entities |
| Entity | PUT | /entity/:entityName | EntitySaga | Create entity |
| Entity | PUT | /entity/:entityName/:entityId | EntitySaga | Update entity |
| Entity | DELETE | /entity/:entityName/:entityId | EntitySaga | Delete entity |
| Calculation | POST | /calculate/:calcName | CalcSaga | Run 2-winding or other calculations |
| Calculation | POST | /calculate/:calcName:bodyType | CalcSaga | Run body-type variants |
| Core | POST | /calculate/core | CalcSaga | Core geometry calculation |
| Fabrication | POST | /calculate/fabrication | CalcSaga | Fabrication calculation |
| CAD | POST | /cad/run-3d-generation | CalcSaga | Trigger CAD/3D generation |
| Storage | GET | /models/:designId.glb | CalcSaga | Load 3D model asset |
| File/LOM | POST | /files/lom | FileSaga | Generate LOM payload and materials |
| Multi-winding | POST | /api/multiWdgCalculator/ | CalcSaga | Dedicated multi-winding calculator |

## Notes on API usage patterns

- The app uses the entity API as a generic CRUD layer for many domain objects such as design, profile, users, lomMaterial, and drawingsStatus.
- The calculation APIs are mostly fire-and-forget from the UI perspective; the reducer stores the returned data and the saga persists relevant values back into the entity store.
- Authentication is centralized in the Axios interceptor, which adds the bearer token and handles 401/403 redirects to login.
- The app does not appear to use a dedicated OpenAPI file or typed client; the endpoints are embedded directly in saga and component code.

## Migration considerations

- The API client layer is already fairly centralized, which is a good starting point for a Flutter migration.
- Endpoints should be grouped by domain (auth, entity, calculation, file, cad) in the target architecture.
- The current implementation mixes persistence and calculation flows in the same saga layer; a future Flutter implementation should separate these concerns.
