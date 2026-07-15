# Calculation Workflows

This document traces the main calculation-driven user flows in the React app.

## 1. Two-winding design workflow

Entry point:
- Home page launches /2windings/new or existing /2windings/:id

Flow:
1. The user opens the two-winding form.
2. Inputs are kept in local component state and mirrored into the calc reducer when the user calculates.
3. The addCalc saga calls the calculation API.
4. The response is stored in the calc.twoWindings slice.
5. The design payload is persisted as an entity and surfaced on the home screen.

Key data domains:
- transformer basics (kVA, voltage, vector group, frequency)
- core geometry
- winding and conductor parameters
- tank/oil formulas and cost values
- comments and locked attributes

Notes:
- This is the main design workflow and the most important migration target.
- The state tree is very large and nested; a Flutter model should preserve its semantics without copy-pasting the whole tree into one class.

## 2. Multi-winding workflow

Entry point:
- Home screen can navigate to /multiwindings/new, but the option is disabled in the current UI.

Flow:
1. The form is split into Part1, Part2, and Part3.
2. The user clicks Calculate.
3. The payload is sent to the dedicated multi-winding backend.
4. The response is mapped into a form-friendly structure.

Notes:
- This workflow is currently less complete than the two-winding flow.
- It uses a different backend service and response mapping utility.

## 3. Core workflow

Entry point:
- CoreModel route, usually reached after a successful two-winding design.

Flow:
1. The page uses values from the two-winding state to build a core request payload.
2. The saga sends the payload to the core calculation API.
3. The returned core geometry is stored in calc.core and displayed in the UI.
4. Users can edit step width/stack values and re-run the calculation.

Notes:
- Core calculation depends heavily on the two-winding state model.
- The UI includes a visual diagram and editable step rows.

## 4. Fabrication workflow

Entry point:
- Fabrication route, usually tied to a two-winding design.

Flow:
1. The page pre-populates the form from values in the two-winding and core state.
2. The user may edit fabrication parameters.
3. Clicking Calculate sends a fabrication payload to the backend.
4. The result is stored in calc.fabrication.
5. The app can trigger 3D generation and watch status updates via socket.io.

Notes:
- This workflow is strongly dependent on upstream design values.
- It also bridges to CAD and drawing status persistence.

## 5. LOM/Cost workflow

Entry point:
- Files route.

Flow:
1. The page builds a LOM payload based on the current fabrication and two-winding state.
2. Material rates are fetched from the entity store.
3. The file saga sends the payload to the LOM service.
4. The returned data is displayed in a table and can be exported to PDF.

Notes:
- This is a document-generation workflow that combines design data and rate tables.
- It may be better modeled as a report-generation feature than as a form workflow.

## 6. 3D generation workflow

Entry point:
- Fabrication page.

Flow:
1. The user requests 3D generation.
2. The app calls the CAD service.
3. The server response triggers drawings status updates.
4. The app loads the model asset from storage when available.

Notes:
- The workflow is asynchronous and event-driven.
- It is a strong candidate for a dedicated state machine in Flutter.

## Migration risks

- The calculation flows are deeply connected to the current state tree and route parameters.
- Several workflows depend on data that is computed earlier in the session, so a Flutter implementation should preserve that dependency chain explicitly.
- The current UI mixes calculation, persistence, and report generation in one screen. This should be split into dedicated business domains during migration.
