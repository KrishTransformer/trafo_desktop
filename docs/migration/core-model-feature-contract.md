# Core Model Feature Contract

This document captures the current React behavior of the core-model workflow so the Flutter desktop migration can preserve request shape, persistence behavior, and screen interactions without guessing backend fields.

Date captured: July 16, 2026

## React source references

- `src/page/coreModel/CoreModel.js`
- `src/page/coreModel/CircularDiagram.js`
- `src/page/coreModel/QuarterCircle.js`
- `src/page/coreModel/CoreModel.css`
- `src/reducers/CalcReducer.js`
- `src/sagas/CalcSaga.js`
- `src/actions/CalcActions.js`
- `src/selectors/CalcSelector.js`

## Route and entry point

- Protected route: `/core/:id`
- The route is typically opened after a two-winding design has already been created or loaded.
- The screen depends on in-memory Redux state, not only the route parameter.

Required upstream state from `calc.twoWindings.data`:

- `designId`
- `core.coreDia`
- `core.limbHt`
- `core.cenDist`
- `lvFormulas.revisedFluxDensity`

Required persisted-design context from the entity store:

- `design.data.data`
- React resolves the design entity id by matching:
  - `item.designId == twoWindings.data.designId`

Important implication for Flutter:

- The core screen cannot be treated as a standalone form.
- It depends on previously loaded two-winding state and a known design entity reference.

## Core backend contract

### Calculation request

- Method: `POST`
- Endpoint: `/calculate/core`
- Triggered by:
  - initial auto-calculate on first load in some cases
  - Calculate button
  - Save button for step edits
  - `Ctrl+Enter` or `Cmd+Enter`

### Request payload shape

React builds the initial payload with these exact JSON field names:

- `coreDiameter`
- `limbHt`
- `cenDist`
- `minimumStepWidth`
- `numberOfSteps`
- `fixtureStepWidth`
- `eCoreBladeType`
- `coreStackRequestList`
- `prevCoreStackRequestList`

Initial values:

- `coreDiameter = twoWindings.data.core.coreDia`
- `limbHt = twoWindings.data.core.limbHt`
- `cenDist = twoWindings.data.core.cenDist`
- `minimumStepWidth = 0`
- `numberOfSteps = 0`
- `fixtureStepWidth = null`
- `eCoreBladeType = "CRUSI_3"`
- `coreStackRequestList = []`
- `prevCoreStackRequestList = []`

If a prior core result already exists and `core.data.coreArea` is present, React backfills:

- `minimumStepWidth = core.data.bldStacks[last].width`
- `numberOfSteps = core.data.bldStacks.length`

### Auto-calculate behavior

On first mount, React automatically calls the core API when all of these are true:

- `twoWindings.data.core.coreDia` exists
- `twoWindings.data.core.coreDia != 0`
- `core.data.coreArea` is not already present

Flutter should preserve this behavior unless product explicitly changes it.

### Step-edit save payload

When the user edits a selected step and presses Save, React sends:

- all current form fields
- `prevCoreStackRequestList`
- `coreStackRequestList`

Construction rules:

- `prevCoreStackRequestList` contains all rows where `row.stepNo < selectedStep`
- `coreStackRequestList` contains exactly one object:
  - `stepNo`
  - `width`
  - `stack`

React does not send a fully rewritten stack table on save. It sends prior rows plus the current edited row.

## Persistence contract after calculation

When `/calculate/core` succeeds:

1. React stores the raw response in `calc.core.data`
2. React serializes the same response into:
   - `core = JSON.stringify(response.data)`
3. React updates the existing design entity with:
   - action equivalent to `addEntity(dataPayload, "design/" + id, true)`

Important behavior to preserve:

- Core calculation updates an existing design record.
- Core calculation does not create a new design record.
- The persisted `core` field is stored as a JSON string.

## Reducer-backed state contract

The React calc reducer initializes `core` with:

- `isLoading`
- `isFullfilled`
- `isAddCompleted`
- `isFailed`
- `data`

Initial `data` shape includes:

- `coreFormulas.noOfSteps`
- `centerLimbStacking`
- `yokeStacking`

The live response shape used by the screen also includes, at minimum:

- `coreArea`
- `coreWeight`
- `designedCoreArea`
- `bldStacks`

`bldStacks` rows are expected to expose:

- `stepNo`
- `width`
- `stack`

Flutter should preserve exact backend field names and avoid inventing additional fields in transport models.

## Screen behavior contract

### Form fields

The React screen exposes:

- Core Diameter
  - read-only display from two-winding state
- Minimum Step Width
- Number Of Steps
- Fixture Step Width
- Blade Type dropdown

Allowed blade type values in the UI:

- `CRUSI_3`
- `BLADE_3`
- `BLADE_4`
- `CRUSI_4`

### Summary metrics

React renders these readouts from current state:

- Gross Core Area = `coreData.coreArea`
- Total Weight = `coreData.coreWeight`
- Flux Density = `twoWindings.data.lvFormulas.revisedFluxDensity.toFixed(3)`
- Designed Core Area = `coreData.designedCoreArea`
- Net Factor = `(designedCoreArea / coreArea).toFixed(3)`

No defensive divide-by-zero handling is added beyond the existing fallback behavior in the component.

### Step table behavior

React shows a step table using `core.data.bldStacks` with columns:

- Step No
- Width
- Stack

Interaction rules:

- when step data first loads, the first row becomes selected
- the step editor is populated from the selected row
- clicking a row updates the selected step
- editing `Width` clears the local edited `stack` field before the next save

### Keyboard shortcut

- `Ctrl+Enter` and `Cmd+Enter` both trigger calculate
- the shortcut is ignored while `core.isLoading` is true

### Loading and error state

- loading state source: `core.isLoading`
- error state source: `core.isFailed`
- success state is inferred from populated `core.data`

## Diagram contract

The React page renders `CircularDiagram` only when:

- `core.data.coreArea` exists
- `stepsData.length > 0`

Diagram input sources:

- `stepsData = core.data.bldStacks`
- `highlightedStep = selectedStep`
- `coreDiameter = twoWindings.data.core.coreDia`

Rendering behavior:

- the diagram mirrors quarter-circle geometry into four quadrants
- each step row is rendered as a rectangular stack segment
- the currently selected step is visually highlighted

Flutter does not need to match React SVG implementation details line-for-line, but it should preserve the same visual meaning and selected-step feedback.

## Print preview contract

- The page exposes a `Print Preview` action.
- React opens a modal-style preview with:
  - `coreData={coreData}`
  - child content label `core`

The migrated Flutter flow should keep a user-visible preview/export entry point for the core result.

## Theme and layout behavior

- The page theme follows `localStorage.getItem("appTheme") === "dark"`
- The layout uses the shared `Layout` shell with:
  - `isThinHeader={true}`
  - `headProps.currentPath = twoWindings.data.designId`
- The page is a two-column desktop-oriented layout:
  - left side form, metrics, and step editing
  - right side diagram

Flutter should keep this as a desktop-first screen and remain usable at `1366x768`.

## Migration implications for Flutter

The Flutter port should keep the workflow split across clear layers:

1. typed request and response models for `/calculate/core`
2. a repository that owns the HTTP call and design-entity update
3. a controller/state object that owns:
   - form state
   - selected step
   - step edit state
   - loading and error state
   - auto-calculate-on-open behavior
4. a presentation layer that renders:
   - desktop form fields
   - step table
   - diagram
   - preview action

## Flutter implementation checklist for the next task

- add typed core request model with the exact JSON field names above
- add typed core response models for:
  - summary values
  - `bldStacks`
- add a core repository contract and HTTP implementation
- resolve the persisted design entity id from loaded design context
- preserve the existing-record update behavior after calculate
- preserve auto-calculate on first open when no core result exists yet
- preserve step-edit save semantics using:
  - `prevCoreStackRequestList`
  - `coreStackRequestList`
- add controller tests for:
  - initial payload construction
  - auto-calculate conditions
  - step selection and save payload building
- add repository tests for:
  - `/calculate/core`
  - persisted design update

## Open migration notes

- React imports `postApi` directly in `CoreModel.js` but performs the actual workflow through Redux action dispatch.
- The helper `calculateLimitedStacks` exists in the component but is currently only logged, not shown as user-facing output.
- The core workflow is tightly coupled to prior two-winding state, so Flutter should avoid exposing the route without a loaded upstream design context.
