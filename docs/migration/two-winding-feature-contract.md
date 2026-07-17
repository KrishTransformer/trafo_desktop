# Two-Winding Feature Contract

This document captures the current React behavior of the two-winding workflow so the Flutter desktop migration can preserve calculation, persistence, and screen behavior without guessing backend fields or UI semantics.

Date captured: July 16, 2026

## React source references

- `src/page/twoWinding/TwoWinding.js`
- `src/page/twoWinding/Part1.js`
- `src/page/twoWinding/Part2.js`
- `src/page/twoWinding/Part3.js`
- `src/page/twoWinding/CoilDimensionsTabs.js`
- `src/reducers/CalcReducer.js`
- `src/sagas/CalcSaga.js`
- `src/actions/CalcActions.js`
- `src/components/table/CheckedTable.js`
- `src/utils/entityPayload.js`

## Route and entry points

- Protected route: `/2windings/:id`
- Home screen opens:
  - `/2windings/new` for a new design
  - `/2windings/:entityId` for an existing design
- Existing design load is primed from Home before navigation:
  - `row.twoWindings` is parsed and pushed into the calc reducer
  - metadata includes:
    - `designId`
    - `createdAt`
    - `entityId`

## Core backend contract

### Calculation request

- Method: `POST`
- Endpoint: `/calculate/2windings/circular`
- Triggered by:
  - Calculate button
  - `Ctrl+Enter` or `Cmd+Enter`

### Persistence after calculation

When the `2windings` calculation succeeds, React immediately creates a new design entity.

- Generated design reference:
  - `${response.data.kVA}k-${randomFiveDigitNumber}`
- Entity create request:
  - Method: `PUT`
  - Endpoint: `/entity/design`
  - Payload fields:
    - `designId`
    - `twoWindings` as a JSON string
- The React saga then refreshes the design list with:
  - `fetchEntity("design", "offset=0&size=100")`

Important behavior to preserve:

- A successful Calculate action creates a new design record.
- React does not update the existing design record during the two-winding calculate path.
- The generated `designId` is assigned into the calculation response before persistence.

### Ownership policy

- Entity payload sanitization strips:
  - `ownerId`
  - `tenantUrl`
  - `tenantURL`
  - `tenentURL`
  - `tenantDatabase`
- Flutter must not reintroduce these fields in persisted payloads.

## Reducer-backed state contract

The React calc reducer initializes `twoWindings` with:

- status flags:
  - `isLoading`
  - `isFullfilled`
  - `isAddCompleted`
  - `isFailed`
- metadata:
  - `createdAt`
  - `designId`
- main data object with these domains:
  - top-level transformer fields
  - `core`
  - `commonFormulas`
  - `tank`
  - `innerWindings`
  - `outerWindings`
  - `coilDimensions`
  - `lvFormulas`
  - `hvFormulas`
  - `tankAndOilFormulas`
  - `cost`
  - `lockedAttributes`
  - `comments`

The reducer shape is large and already acts as the behavioral contract. Flutter should preserve field names exactly when talking to the backend.

## Top-level field defaults from React

Notable defaults in `initialState.twoWindings.data`:

- `eTransBodyType: "CIRCULAR"`
- `eTransCostType: "ECONOMIC"`
- `lowVoltage: 433`
- `highVoltage: 11000`
- `lVConductorMaterial: "Cu"`
- `hVConductorMaterial: "Cu"`
- `lvCurrentDensity: "4.24"`
- `hvCurrentDensity: "4.24"`
- `lvWindingType: "HELICAL"`
- `hvWindingType: "HELICAL"`
- `frequency: "50"`
- `vectorGroup: "Dyn11"`
- `buildFactor: 1.3`
- `isOLTC: false`
- `isCSP: false`
- `eRadiatorType: "RADIATOR"`

Nested defaults worth preserving:

- `core.coreType: "PRIME"`
- `core.coreMaterial: "NipM4"`
- `innerWindings.isEnamel: false`
- `outerWindings.isEnamel: false`
- all lock flags start as `false`

## Form sections in the React UI

### Part 1

- transformer type and cost mode
- `kVA`
- LV/HV voltage and winding types
- frequency
- LV/HV conductor material and current density
- vector group and optional limb settings
- core material, build factor, flux density
- tap step settings and OLTC/OCTC
- core geometry:
  - `coreDia`
  - `limbHt`
  - `cenDist`
  - `area`
  - `coreType`
  - `specificLoss`
- loss and impedance values:
  - tank loss
  - load loss
  - core loss
  - limit EZ
  - EZ

### Part 2

Mirrored LV/HV winding section with:

- turns per phase
- phase current
- current density
- conductor cross section
- conductor sizes
- conductor insulation
- no. in parallel
- winding length
- number of layers
- inter-layer insulation
- duct counts and widths
- disc duct size
- turns/layer
- end clearances
- eddy/stray loss
- temperature gradient
- conductor weights
- load loss
- terminal type

### Part 3

- coil clearances:
  - `coilDimensions.coreGap`
  - `coilDimensions.lvhvgap`
  - `coilDimensions.hvhvgap`
- comments panel
- expandable “More Info” tabs:
  - Tank & Cooling or Enclosure & Temp
  - Coil Dimensions
  - Costings

## Derived UI behavior to preserve

### Dry type behavior

If `dryType` becomes true:

- `dryTempClass` defaults to `CLASS_B` if missing
- `windingTemp` is driven by:
  - `CLASS_B -> "70"`
  - `CLASS_F -> "90"`
  - `CLASS_H -> "115"`
- oil-specific fields disappear from the cooling tab

### Cost mode behavior

If `eTransCostType` changes:

- `ECONOMIC`
  - copper current density becomes `4.24`
  - aluminium current density becomes `2.37`
- `ENERGY_EFFICIENT`
  - copper current density becomes `1.7`
  - aluminium current density becomes `0.9`

This is applied independently to LV and HV based on each conductor material field.

### kVA heuristic behavior

Changing `kVA` automatically resets these fields:

- `kVA <= 2500`
  - `highVoltage = 11000`
  - `lowVoltage = 433`
  - `hvWindingType = "HELICAL"`
  - `lvWindingType = "HELICAL"`
  - `fluxDensity = 1.7333`

- `2500 < kVA <= 20000`
  - `highVoltage = 33000`
  - `lowVoltage = 11000`
  - `hvWindingType = "DISC"`
  - `lvWindingType = "HELICAL"`
  - `fluxDensity = 1.69`

- `kVA > 20000`
  - `highVoltage = 132000`
  - `lowVoltage = 33000`
  - `hvWindingType = "DISC"`
  - `lvWindingType = "DISC"`
  - `fluxDensity = 1.69`

### Flux density clamp

- If `kVA <= 2500`, `fluxDensity` cannot exceed `1.7333`
- If `kVA > 2500`, `fluxDensity` cannot exceed `1.69`

### Reset cascades

React resets downstream fields when certain upstream values change. Flutter should preserve these cascades.

Examples:

- changing `core.coreDia` or `core.limbHt` resets large parts of:
  - `innerWindings`
  - `outerWindings`
  - `tankLoss`
  - `coilDimensions`
- changing `vectorGroup` resets:
  - both winding sections
  - `tankLoss`
  - `coilDimensions`
  - most of `core`, while preserving `coreMaterial`
- changing `fluxDensity` resets:
  - both winding sections
  - `tankLoss`
  - most of `core`, while preserving lock-controlled values and `coreMaterial`
  - selected `coilDimensions` gap fields
- changing tap step fields resets `outerWindings`

## Lock behavior contract

React tracks editable lock state under:

- `lockedAttributes.coreLock`
- `lockedAttributes.innerWindings`
- `lockedAttributes.outerWindings`

Important rules:

- `conductorSizes` and `noInParallel` should not stay locked together for the same winding section
- when `conductorSizes` is toggled, `condBreadth` and `condHeight` mirror that lock state
- if both `coreLock.coreDia` and `coreLock.limbHt` are true, React clears `noInParallel` locks for both windings
- unlocking `core.coreDia` can implicitly initialize `core.limbHt` lock state
- in some cases React prevents enabling a conductor-size lock when `core.limbHt` is already locked

### Payload nulling before calculate

Before calling `/calculate/2windings/circular`, React clones the form state and nulls unlocked fields inside locked sections:

- unlocked `innerWindings` locked-field entries are sent as `null`
- unlocked `outerWindings` locked-field entries are sent as `null`
- unlocked `coreLock` fields inside `core` are sent as `null`

This nulling behavior is part of the backend contract and should be preserved.

## Comments behavior

The comments panel is populated from two sources:

1. Persistent disc-winding notes, derived from:
   - `lvFormulas.lvWidthOfSpacer`
   - `lvFormulas.lvNoOfSpacers`
   - `hvFormulas.hvWidthOfSpacer`
   - `hvFormulas.hvNoOfSpacers`

2. Hover comments from `data.comments`, using keys:
   - `tapStepComment`
   - `wattPerKgComment`
   - `lvCondInsComment`
   - `hvCondInsComment`
   - `lvInterLayerInsComment`
   - `hvInterLayerInsComment`
   - `lvDuctWidthComment`
   - `hvDuctWidthComment`
   - `lvEndClrComment`
   - `hvEndClrComment`
   - `coreToLvClrComment`
   - `lvToHvClrComment`
   - `hvToHvClrComment`

If neither source is available, React shows an empty-state helper message.

## Existing design load behavior

From the Home table:

- `row.twoWindings` is parsed and loaded into calc state
- optional related persisted blobs are also loaded if present:
  - `row.core`
  - `row.fabrication`
  - `row.lom`
- then navigation goes to `/2windings/${row.id}`

This means the two-winding screen relies on route state and in-memory calc state together.

## Screen-level interaction behavior

- page theme follows the shared dark-mode flag stored in `localStorage`
- Calculate button shows a spinner while `twoWindings.isLoading`
- Reset clears calc state and scrolls the page to top
- Calculate also scrolls the page to top
- comments rely on hover events from specific inputs
- More Info is a local accordion, collapsed by default

## Migration implications for Flutter

The Flutter port should not start with one giant mutable map in the widget tree. The safer structure is:

1. typed request/response models for the persisted and calculated two-winding payload
2. a controller/state object that owns:
   - editable form state
   - metadata
   - loading/error state
   - lock state
   - comment state
3. explicit helper methods for:
   - upstream reset cascades
   - dry-type and cost-mode defaults
   - lock toggling rules
   - calculate payload sanitization
   - create-new-design persistence

## Flutter implementation checklist for the next task

- add typed two-winding domain models without inventing fields
- add a calculation repository for `/calculate/2windings/circular`
- add a persistence repository path for creating design entities
- preserve the “calculate creates a new design record” rule
- preserve lock-nulling behavior in the calculate payload
- support `/2windings/new` and `/2windings/:designId`
- build the desktop screen in three sections matching the React layout
- keep the screen usable at `1366x768`
- add tests for:
  - kVA auto-default logic
  - dry-type temperature mapping
  - lock behavior and payload nulling
  - calculation request and entity-create side effects

## Open migration notes

- React currently hardcodes the body type suffix as `/circular` in the calculate call.
- React generates the `designId` client-side with a random five-digit suffix.
- React creates a new record on calculate even when the route is an existing entity id.
- If that create-on-recalculate behavior is still required by product policy, Flutter should keep it exactly as-is.
