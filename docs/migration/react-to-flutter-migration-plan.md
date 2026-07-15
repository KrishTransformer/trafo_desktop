# React to Flutter Migration Plan

This document outlines a migration-oriented plan for moving the current React application to Flutter without implementing Flutter code yet.

## Scope and goals

The main goal is to preserve the current user journeys for:
- authentication
- design listing and search
- 2-winding design calculations
- core/fabrication workflows
- files/LOM reporting
- profile and user administration

## Proposed migration phases

### Phase 1 — Domain model and routing
- Create Flutter route definitions for the public and protected screens.
- Map the current React screens to Flutter page widgets.
- Define the core domain objects for design, core, fabrication, profile, and user entities.
- Preserve route parameters such as design id.

### Phase 2 — State management
- Replace the Redux/saga model with a Flutter-friendly architecture such as Riverpod, Bloc, or Provider.
- Keep the current domain boundaries from the React app:
  - auth state
  - entity state
  - calculation state
  - file/LOM state
- Introduce typed models for the most complex nested payloads, especially the two-winding and fabrication forms.

### Phase 3 — API layer
- Wrap the current backend endpoints in repository classes.
- Preserve the existing service split:
  - auth repository
  - entity repository
  - calculation repository
  - file/LOM repository
  - CAD/storage repository
- Introduce a common error and loading-state strategy.

### Phase 4 — Screen migration
- Migrate the screens in the following order:
  1. Login / sign-up / forgot password
  2. Home / design list
  3. Two-winding design
  4. Core model
  5. Fabrication
  6. Files / LOM / PDF output
  7. Profile and users
- Keep the screen behavior and validation behavior aligned with the current app where possible.

### Phase 5 — Validation and QA
- Reproduce the current screen inventory in Flutter and validate:
  - route coverage
  - form field parity
  - success/error/loading states
  - API integration points
- Flag any behaviors that are unclear or duplicated in the current React app before implementation.

## High-risk areas

- The two-winding and fabrication workflows contain the largest and deepest state trees.
- The CAD/3D generation and socket-based status updates should be modeled as asynchronous state machines rather than ad-hoc callbacks.
- The generic entity CRUD layer is flexible but not strongly typed; this may become a source of migration complexity.
- The multi-winding flow is less mature and may need a scoped implementation plan.

## Unclear or duplicated behavior to review before implementation

- Multi-winding is present but not fully surfaced in the home screen.
- Several screens use similar CRUD and state update patterns with overlapping responsibilities.
- Form validation is implemented inconsistently across screens.
- Some screens appear to mix persistence, calculation, and report generation logic in one place.

## Recommended migration strategy

- Treat the React app as a source of behavior and not as a literal component-by-component port.
- Rebuild the user journeys as Flutter screens with clearer state boundaries.
- Prefer typed domain models over raw nested JSON maps for calculation-heavy flows.
- Keep the backend contract stable initially so the migration can focus on UI and state architecture.
