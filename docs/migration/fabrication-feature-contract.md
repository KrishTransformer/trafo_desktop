# Fabrication Feature Contract

This document captures the current React behavior of the fabrication workflow so the Flutter desktop migration can preserve calculation inputs, persisted fabrication data, and the asynchronous 3D generation flow without guessing backend fields.

Date captured: July 16, 2026

## React source references

- `src/page/fabrication/Fabrication.js`
- `src/page/fabrication/Part1.js`
- `src/page/fabrication/Part2.js`
- `src/page/fabrication/Part3.js`
- `src/page/fabrication/AccessoriesTabs.js`
- `src/page/fabrication/OtherTabs.js`
- `src/page/fabrication/tabsContent/Accessories1.js`
- `src/page/fabrication/tabsContent/Accessories2.js`
- `src/page/fabrication/tabsContent/Terminal.js`
- `src/page/fabrication/tabsContent/Stiffners.js`
- `src/page/fabrication/tabsContent/Misc.js`
- `src/page/fabrication/FabricationTheme.css`
- `src/reducers/CalcReducer.js`
- `src/sagas/CalcSaga.js`
- `src/selectors/CalcSelector.js`

## Route and entry point

- Protected route: `/fabrication/:id`
- The route is typically opened after a saved two-winding design exists.
- The workflow depends on in-memory upstream calculation state, not only the route parameter.

Required upstream state:

- `calc.twoWindings.data`
- `calc.core.data`
- `entity.design.data.data`
- `entity.drawingsStatus.data.data`
- `calc.generate3d`

Important implication for Flutter:

- Fabrication cannot be modeled as a standalone CRUD form.
- It depends on persisted design identity, two-winding derived geometry, optional core data, and a separate CAD status stream.

## Fabrication backend contract

### Calculation request

- Method: `POST`
- Endpoint: `/calculate/fabrication`
- Triggered by:
  - Calculate button
  - `Ctrl+Enter` or `Cmd+Enter`
  - an initial auto-calculate in some cases

### Persistence after calculation

When `/calculate/fabrication` succeeds:

1. React stores the raw response in `calc.fabrication.data`
2. React serializes the same response into:
   - `fabrication = JSON.stringify(response.data)`
3. React updates the existing design entity with:
   - action equivalent to `addEntity(dataPayload, "design/" + id, true)`

Important behavior to preserve:

- Fabrication calculation updates an existing design record.
- Fabrication calculation does not create a new design record.
- The persisted `fabrication` field is stored as a JSON string.

## Reducer-backed state contract

The React calc reducer initializes `fabrication` with:

- `isLoading`
- `isFullfilled`
- `isAddCompleted`
- `isFailed`
- `data`

The initialized `data` object is large and nested. The main sections are:

- `tank`
- `stiffner`
- `radiator`
- `fill_Vlv`
- `drain_Vlv`
- `smpl_Vlv`
- `tank_LiftLug`
- `jackpad`
- `hvb`
- `lvb`
- `hvcb`
- `lvcb`
- `lid`
- `cons`
- `buch_Rely`
- `gorPipe`
- `mog`
- `exp_Vent`
- `inspect`
- `bot_Chnl`
- `roller`
- `cf`
- `lid_LiftLug`
- `thermoPkt`
- `restOfVariables`
- `fabricationCore`
- `coreFoot`
- `lift_Cons`
- `hv`
- `lv`
- `hvct`
- `lvct`
- `octcFlange`

Boolean defaults worth preserving:

- `fill_Vlv.fill_Vlv = true`
- `drain_Vlv.drain_Vlv = true`
- `smpl_Vlv.smpl_Vlv = true`
- `hvcb.hvcb = false`
- `lvcb.lvcb = false`
- `mog.mog = false`
- `exp_Vent.exp_Vent = true`
- `exp_Vent.exp_Vent_With_OI = false`
- `bot_Chnl.isRoller = false`
- `roller.roller = true`
- `lid_LiftLug.lid_LiftLug = true`
- `thermoPkt.thermoPkt1 = false`
- `thermoPkt.thermoPkt2 = false`
- `octcFlange.isoctc = false`
- `hvb.hvb_Pos = "lid"`
- `lvb.lvb_Pos = "lid"`
- `gorPipe.buchholz_Relay = false`
- `gorPipe.single_Valve = true`
- `gorPipe.valve_Type1 = true`

Flutter should preserve backend field names exactly and avoid inventing extra transport fields.

## Initial form-state seeding from upstream calculations

React seeds the editable fabrication form from the current `fabrication.data`, then overlays upstream values from `twoWindings` and `core`.

### `restOfVariables`

React fills:

- `designId = twoWindings.data.designId`
- `kVA = twoWindings.data.kVA`
- `transformer_Weight = twoWindings.data.tankAndOilFormulas.transformerWeight`
- `limb_CC = twoWindings.data.core.cenDist`
- `limb_Nos = core.data.numberOfSteps`
- `limb_H = twoWindings.data.core.limbHt`

Important note:

- `handleFabCalculate()` later hardcodes `limb_Nos: 3` in the actual request payload instead of using `formState.restOfVariables.limb_Nos`.
- Flutter should treat that discrepancy as part of the current behavior unless product explicitly changes it.

### `tank`

React fills:

- `tank_L = twoWindings.data.tank.tankLength`
- `tank_W = twoWindings.data.tank.tankWidth`
- `tank_H = twoWindings.data.tank.tankHeight`
- `tank_Thick = twoWindings.data.tank.tankWallThickness`
- `tank_Bot_Thick = twoWindings.data.tank.tankBottomThickness`
- `tank_Flg_Thick = twoWindings.data.tank.frameThickness`

### `radiator`

React fills:

- `radiator_CC = twoWindings.data.tankAndOilFormulas.radiatorHeight`
- `radiator_W = twoWindings.data.tankAndOilFormulas.radiatorWidth`
- `radiator_Fin_Nos = twoWindings.data.tankAndOilFormulas.noOfFinsPerRadiator`
- `radiator_Nos = twoWindings.data.tankAndOilFormulas.noOfRadiators`
- `radiator_Left_Nos = noOfRadiators / 2`
- `radiator_Right_Nos = noOfRadiators / 2`

### Other seeded sections

- `lid.lid_Thick = twoWindings.data.tank.tankLidThickness`
- `hvb.hvb_Volt = twoWindings.data.highVoltage`
- `hvb.hvb_Amp = twoWindings.data.tankAndOilFormulas.hvBushingCurrent`
- `lvb.lvb_Volt = twoWindings.data.lowVoltage`
- `lvb.lvb_Amp = twoWindings.data.tankAndOilFormulas.lvBushingCurrent`
- `cons.cons_Vol = twoWindings.data.tankAndOilFormulas.conservatorCapacity`
- `cons.cons_Dia = twoWindings.data.tankAndOilFormulas.conservatorDia`
- `cons.cons_L = twoWindings.data.tankAndOilFormulas.conservatorLength`
- `fabricationCore.core_Dia = twoWindings.data.core.coreDia`
- `lv.lv_ID = twoWindings.data.coilDimensions.lvid`
- `lv.lv_OD = twoWindings.data.coilDimensions.lvod`
- `lv.lv_Wdg_L = twoWindings.data.innerWindings.windingLength`
- `lv.lv_Volts = twoWindings.data.innerWindings.turnsPerPhase`
- `hv.hv_ID = twoWindings.data.coilDimensions.hvid`
- `hv.hv_OD = twoWindings.data.coilDimensions.hvod`
- `hv.hv_Wdg_L = twoWindings.data.outerWindings.windingLength`

## Auto-calculate behavior

On first mount, React automatically calls the fabrication calculate path when:

- `fabrication.data.tank.tank_L == ""`

The screen also:

- fetches `drawingsStatus` for the current `designId`
- attempts to load the 3D model blob if `generate3d.data.blob` is not already present

Flutter should preserve this initialization behavior unless product explicitly changes it.

## Fabrication calculation payload contract

React does not submit the full nested `formState` object to `/calculate/fabrication`.
It flattens the request into a large top-level object.

Representative top-level groups in the payload:

- design metadata
  - `designId`
  - `kVA`
  - `eVectorGroup`
- transformer/tank dimensions
  - `transformer_Weight`
  - `limb_CC`
  - `limb_Nos`
  - `limb_H`
  - `tank_L`
  - `tank_W`
  - `tank_H`
  - `tank_Thick`
  - `tank_Bot_Thick`
  - `tank_Flg_Thick`
- radiator
  - `radiator_CC`
  - `radiator_W`
  - `radiator_Fin_Nos`
  - `radiator_Nos`
  - `radiator_Left_Nos`
  - `radiator_Right_Nos`
- lid/conservator
  - `lid_Thick`
  - `cons_Vol`
  - `cons_Dia`
  - `cons_L`
- bushings / cable-box position
  - `hvb_Volt`
  - `hvb_Amp`
  - `lvb_Volt`
  - `lvb_Amp`
  - `hvb_Pos`
  - `lvb_Pos`
  - `hvcb`
  - `lvcb`
- active/core/winding dimensions
  - `core_Dia`
  - `lv_ID`
  - `lv_OD`
  - `lv_Wdg_L`
  - `lv_Volts`
  - `hv_ID`
  - `hv_OD`
  - `hv_Wdg_L`
- valves and accessories
  - `drain_Vlv`
  - `drain_Vlv_Nos`
  - `smpl_Vlv`
  - `smpl_Vlv_Nos`
  - `fill_Vlv`
  - `roller`
  - `roller_Type`
  - `mog`
  - `buchholz_Relay`
  - `single_Valve`
  - `valve_Type1`
  - `mog_Tlt_Ang`
  - `prv`
  - `exp_Vent`
  - `exp_Vent_ID`
  - `radiator_Vlv`
  - `lid_LiftLug`
  - `lid_LiftLug_Thick`
  - `mbox`
  - `mbox_Inst_Nos`
  - `thrmo_Syphn`
  - `roller_Guage`
  - `thermoPkt1`
  - `thermoPkt2`
  - `exp_Vent_With_OI`
  - `isRoller`
- tap/output values
  - `turnsPerTap`
  - `tapVoltages`
  - `tapCurrent`
  - `tapStepPercentage`
  - `isOCTC`

### Nested `printouts` payload

React embeds a nested `printouts` object containing report-oriented values:

- `kva`
- `voltsAtHv`
- `voltsAtLv`
- `amperesHv`
- `amperesLv`
- `phasesHv`
- `phasesLv`
- `frequency`
- `impedance`
- `vectorGroup`
- `topOilTemp`
- `windingTemp`
- `coolingType`
- `weightsOfActivePart`
- `oilWeight`
- `totalOil`
- `basicInsulationLevelHV`
- `basicInsulationLevelLV`
- `ampsHV`
- `ampsLV`
- `tappingHVVariations`
- `lossesAt50`
- `lossesAt100`
- `weightOfTankAndAcc`

Important behavior to preserve:

- JSON field names are not normalized into nested sections for the request.
- The fabrication API contract currently expects this flattened payload shape.

## Special UI-side field behaviors

`handleInputChange()` has special-case coupling beyond a generic nested update:

### Buchholz relay coupling

If `gorPipe.buchholz_Relay` changes, React also sets:

- `gorPipe.single_Valve = true`
- `gorPipe.valve_Type1 = true`

### HV cable-box coupling

If `hvcb.hvcb` changes:

- `hvcb.hvcb = value`
- `hvb.hvb_Pos = "tank"` when true
- `hvb.hvb_Pos = "lid"` when false

### LV cable-box coupling

If `lvcb.lvcb` changes:

- `lvcb.lvcb = value`
- `lvb.lvb_Pos = "tank"` when true
- `lvb.lvb_Pos = "lid"` when false

Flutter should preserve these coupled updates explicitly in controller logic.

## Screen structure contract

The React desktop screen is split into three columns:

### Column 1

- design reference summary
- core details summary
- tank details form
- radiator details form

### Column 2

- lid and conservator details
- tabbed active-part and tank-foundation sections

### Column 3

- accessories / fittings section with tabs:
  - `Accessories (1)`
  - `Accessories (2)`
  - `Terminals`
  - `Stiffeners`
  - `Misc`
- embedded 3D preview panel
- maximize/open 3D preview modal
- Calculate button
- Generate 3D / Show Status button
- right-side drawer for 3D generation status

## 3D generation workflow contract

Fabrication owns a second workflow separate from calculation.

### Generate 3D request

- Method: `POST`
- Endpoint: `/cad/run-3d-generation`
- Params:
  - `fileName = formState.restOfVariables.designId`
  - `skipBatRun = "no"`
- Payload:
  - React flattens all nested sections of `formState` into one top-level object by spreading every nested section into one merged object.

### Drawings status persistence

If the CAD response message contains `"fabrication"`:

- React adds an entity in `drawingsStatus` with:
  - `designId = params.fileName`
  - `message = "Generate 3D Requested"`
  - `status = "Success"`

Before generating 3D, React deletes existing `drawingsStatus` records for the current `designId`.

### 3D model loading

- Method: `GET`
- Endpoint: `/models/:designId.glb`
- Service: storage service
- Response is expected as a `blob`
- React converts the blob into an object URL and stores it in `calc.generate3d.data.blob`

### Status polling / socket behavior

When the drawer is open, React connects to:

- `https://tf-cad-service.trafointel.com`

Behavior:

- on socket `message`, React refreshes `drawingsStatus`
- on unmount or drawer close, React disconnects

### Generate-3D button gating

React gates `Generate 3D` using several conditions:

- local dirty markers:
  - `allow3DButton1`
  - `allow3DButton2`
- whether `drawingsStatus` already has entries
- whether an existing blob URL is already loaded
- whether the latest status message includes `"Process finished!"`
- whether the oldest tracked status is more than 45 minutes old

Important migration implication:

- This is an explicit state machine candidate in Flutter.
- The current React logic is spread across several local booleans and effects and should be made more explicit during migration while preserving behavior.

## Fabrication status drawer contract

The drawer shows:

- title: `Fabrication 3D Generation Status`
- total duration derived from first and last `drawingsStatus.createdAt`
- current success/processing state based on the latest message
- vertical step list of status records with:
  - created time
  - message
  - icon based on status

Latest-message success rule:

- success is inferred when the latest message includes `"Process finished!"`

## Existing persisted fabrication load behavior

React updates the editable form from persisted fabrication data when:

- `fabrication.data.restOfVariables.designId` exists

Effect:

- `setFormState(fabrication.data)`

This means fabrication can resume from a saved entity record while still depending on the currently loaded two-winding design context.

## Theme and keyboard behavior

- Theme follows `localStorage.getItem("appTheme") === "dark"`
- `Layout` uses:
  - `isThinHeader={true}`
  - `headProps.currentPath = twoWindings.data.designId`
- `Ctrl+Enter` and `Cmd+Enter` both trigger fabrication calculate while not loading

## Migration implications for Flutter

The Flutter port should keep fabrication split across clear layers:

1. typed calculation request/response models for `/calculate/fabrication`
2. a repository for fabrication calculate and persisted-design update
3. a separate repository or service boundary for:
   - CAD generation request
   - drawings-status entity operations
   - storage blob/model loading
4. a controller or state machine that owns:
   - editable fabrication form state
   - upstream seeded defaults from two-winding/core
   - dirty/generate gating state
   - CAD status timeline
   - 3D preview availability
5. a presentation layer that keeps the three-column desktop workflow usable at `1366x768`

## Flutter implementation checklist for the next task

- add typed fabrication request and response models without inventing fields
- preserve the flattened calculate payload shape
- add fabrication repositories for:
  - `/calculate/fabrication`
  - persisted design update with serialized `fabrication`
- add CAD workflow repositories/services for:
  - `/cad/run-3d-generation`
  - `/models/:designId.glb`
  - `drawingsStatus` CRUD
- preserve the special coupled field behaviors:
  - buchholz relay
  - HV cable box / HV bushing position
  - LV cable box / LV bushing position
- preserve auto-calculate on initial open when fabrication tank length is empty
- add tests for:
  - initial seeding from two-winding and core
  - flattened calculate payload building
  - fabrication persisted update
  - generate-3D request and drawings-status side effects
  - gating logic for Generate 3D vs Show Status

## Open migration notes

- The current React fabrication request mixes pure fabrication parameters with print/report values in the same API call.
- `limb_Nos` is seeded from core state in form setup but later hardcoded to `3` in calculate; Flutter should preserve this unless the backend contract is explicitly corrected.
- The React implementation mixes calculation, CAD orchestration, status tracking, and 3D preview in one component. Flutter should keep those behaviors but model them with clearer boundaries.
