# Files Feature Contract

This document captures the current React behavior of the files workflow so the Flutter desktop migration can preserve LOM generation, rate overrides, PDF/export actions, and persistence behavior without guessing backend fields.

Date captured: July 16, 2026

## React source references

- `src/page/files/Files.js`
- `src/page/files/FilesTheme.css`
- `src/page/files/Tabledata.json`
- `src/actions/FileActions.js`
- `src/reducers/FileReducer.js`
- `src/sagas/FileSaga.js`
- `src/selectors/CalcSelector.js`
- `src/selectors/EntitySelector.js`

## Route and entry point

- Protected route: `/files/:id`
- The route is typically opened after two-winding and fabrication data already exist.
- The workflow depends on in-memory Redux state, not only the route parameter.

Required upstream state:

- `calc.twoWindings.data`
- `calc.fabrication.data`
- `calc.core.data`
- `entity.design.data.data`
- `entity.lomMaterial.data.data`
- `file.lom`
- `file.customer`

Important implication for Flutter:

- The files screen cannot be modeled as an isolated document page.
- It depends on current calculated design data, a material master list fetched through the generic entity API, and a local file reducer that also stores ad-hoc customer details.

## Files backend contract

### LOM generation request

- Method: `POST`
- Endpoint: `/files/lom`
- Service bucket in React: `CORE_SERVICE`
- Triggered by:
  - initial screen load after the material list is available
  - any upstream change to `fabrication`
  - any upstream change to `twoWindings`
  - any material-rate override edit

### Request payload shape

React sends this exact top-level JSON shape:

- `isTrue`
- `lomBooleans`
- `lomQuantity`
- `lomRate`

React currently hardcodes:

- `isTrue = true`

### `lomBooleans` contract

React builds these exact boolean keys:

- `hvCableBox`
- `lvCableBox`
- `hvBushing`
- `lvBushing`
- `permaWood`
- `drainValve`
- `filterValve`
- `samplingValve`
- `relayShutOffValve`
- `thermometerPocket`
- `airReleasePlug`
- `oltc`
- `octc`
- `oti`
- `wti`
- `buchholzRelay`
- `marshallingBox`
- `oilLevelGauge`
- `mog`
- `pressureReliefValve`
- `oilCirculatingPump`
- `avrrtcc`
- `rollers`
- `pumpControlCubicle`
- `biMetallicConnector`
- `fasteners`

Representative derivations:

- `hvCableBox = fabrication.data.hvcb.hvcb == false ? false : true`
- `lvCableBox = fabrication.data.lvcb.lvcb == false ? false : true`
- `hvBushing = fabrication.data.hvcb.hvcb == false ? true : false`
- `lvBushing = fabrication.data.lvcb.lvcb == false ? true : false`
- `drainValve = fabrication.data.drain_Vlv.drain_Vlv`
- `filterValve = fabrication.data.fill_Vlv.fill_Vlv`
- `samplingValve = fabrication.data.smpl_Vlv.smpl_Vlv`
- `oltc = twoWindings.data.isOLTC`
- `octc = twoWindings.data.isOLTC === true ? false : true`
- `oilLevelGauge = twoWindings.data.isCSP === false ? true : false`
- `mog = fabrication.data.mog.mog`
- `pressureReliefValve = fabrication.data.restOfVariables.prv`
- `rollers = fabrication.data.roller.roller`

React also hardcodes several values to `true`:

- `permaWood`
- `relayShutOffValve`
- `thermometerPocket`
- `airReleasePlug`
- `oti`
- `wti`
- `buchholzRelay`
- `marshallingBox`
- `oilCirculatingPump`
- `avrrtcc`
- `pumpControlCubicle`
- `biMetallicConnector`
- `fasteners`

### `lomQuantity` contract

React builds these exact quantity keys:

- `lamination`
- `hvConductor`
- `lvConductor`
- `hvConnectionLeads`
- `lvConnectionLeads`
- `insulationMaterial`
- `transformerOil`
- `tankLidEtc`
- `hvCableBox`
- `lvCableBox`
- `hvBushing`
- `lvBushing`
- `radiatorsAndHeatExc`
- `permaWood`
- `drainValve`
- `filterValve`
- `samplingValve`
- `relayShutOffValve`
- `breatherSilicaGel`
- `ratingPlate`
- `thermometerPocket`
- `airReleasePlug`
- `coreBoltsAndTieRods`
- `oltc`
- `octc`
- `oti`
- `wti`
- `buchholzRelay`
- `marshallingBox`
- `oilLevelGauge`
- `mog`
- `pressureReliefValve`
- `oilCirculatingPump`
- `avrrtcc`
- `rollers`
- `pumpControlCubicle`
- `biMetallicConnector`
- `fasteners`
- `otherMaterials`

Representative derivations:

- `lamination = twoWindings.data.core.coreWeight`
- `hvConductor = twoWindings.data.hvFormulas.hvProcurementWeight`
- `lvConductor = twoWindings.data.lvFormulas.lvProcurementWeight`
- `hvConnectionLeads = twoWindings.data.tankAndOilFormulas.hvConnectionWeight`
- `lvConnectionLeads = twoWindings.data.tankAndOilFormulas.lvConnectionWeight`
- `insulationMaterial = twoWindings.data.tankAndOilFormulas.insulationWeight`
- `transformerOil = twoWindings.data.tankAndOilFormulas.totalOil`
- `tankLidEtc = twoWindings.data.tankAndOilFormulas.weightOfTankAndAcc`
- `hvBushing = twoWindings.data.vectorGroup.charAt(0) == "D" ? 3 : 4`
- `lvBushing = twoWindings.data.vectorGroup.charAt(1) == "d" ? 3 : 4`
- `radiatorsAndHeatExc = twoWindings.data.tankAndOilFormulas.totalRadiatorWeight`
- `drainValve = fabrication.data.drain_Vlv.drain_Vlv_Nos`
- `filterValve = fabrication.data.fill_Vlv.fill_Vlv_Nos`
- `samplingValve = fabrication.data.smpl_Vlv.smpl_Vlv_Nos`
- `coreBoltsAndTieRods = twoWindings.data.tankAndOilFormulas.channelWeight`
- `oilLevelGauge = fabrication.data.cons.cons_Olg_Nos`

React also hardcodes several numeric values:

- `hvCableBox = 1`
- `lvCableBox = 1`
- `permaWood = 0.0`
- `relayShutOffValve = 0.0`
- `breatherSilicaGel = 1`
- `ratingPlate = 1`
- `thermometerPocket = 1`
- `airReleasePlug = 0.0`
- `oltc = 1`
- `octc = 1`
- `oti = 0.0`
- `wti = 0.0`
- `buchholzRelay = 0.0`
- `marshallingBox = 0.0`
- `mog = 1`
- `pressureReliefValve = 0.0`
- `oilCirculatingPump = 0.0`
- `avrrtcc = 0.0`
- `rollers = 4`
- `pumpControlCubicle = 0.0`
- `biMetallicConnector = 0.0`
- `fasteners = 0.0`
- `otherMaterials = 0.0`

### `lomRate` contract

React builds these exact rate keys:

- `lamination`
- `hvConductor`
- `lvConductor`
- `hvConnectionLeads`
- `lvConnectionLeads`
- `insulationMaterial`
- `transformerOil`
- `tankLidEtc`
- `hvCableBox`
- `lvCableBox`
- `hvBushing`
- `lvBushing`
- `radiatorsAndHeatExc`
- `permaWood`
- `drainValve`
- `filterValve`
- `samplingValve`
- `relayShutOffValve`
- `breatherSilicaGel`
- `ratingPlate`
- `thermometerPocket`
- `airReleasePlug`
- `coreBoltsAndTieRods`
- `oltc`
- `octc`
- `oti`
- `wti`
- `buchholzRelay`
- `marshallingBox`
- `oilLevelGauge`
- `mog`
- `pressureReliefValve`
- `oilCirculatingPump`
- `avrrtcc`
- `rollers`
- `pumpControlCubicle`
- `biMetallicConnector`
- `fasteners`
- `otherMaterials`

Rate values are mapped by index from `lomMaterial.data.data`:

- `materialData[0] -> lamination`
- `materialData[1] -> hvConductor`
- `materialData[2] -> lvConductor`
- `materialData[3] -> hvConnectionLeads`
- `materialData[4] -> lvConnectionLeads`
- `materialData[5] -> insulationMaterial`
- `materialData[6] -> transformerOil`
- `materialData[7] -> tankLidEtc`
- `materialData[8] -> hvCableBox`
- `materialData[9] -> lvCableBox`
- `materialData[10] -> hvBushing`
- `materialData[11] -> lvBushing`
- `materialData[12] -> radiatorsAndHeatExc`
- `materialData[13] -> permaWood`
- `materialData[14] -> drainValve`
- `materialData[15] -> filterValve`
- `materialData[16] -> samplingValve`
- `materialData[17] -> relayShutOffValve`
- `materialData[18] -> breatherSilicaGel`
- `materialData[19] -> ratingPlate`
- `materialData[20] -> thermometerPocket`
- `materialData[21] -> airReleasePlug`
- `materialData[22] -> coreBoltsAndTieRods`
- `materialData[23] -> oltc`
- `materialData[24] -> octc`
- `materialData[25] -> oti`
- `materialData[26] -> wti`
- `materialData[27] -> buchholzRelay`
- `materialData[28] -> marshallingBox`
- `materialData[29] -> oilLevelGauge`
- `materialData[30] -> mog`
- `materialData[31] -> pressureReliefValve`
- `materialData[32] -> oilCirculatingPump`
- `materialData[33] -> avrrtcc`
- `materialData[34] -> rollers`
- `materialData[35] -> pumpControlCubicle`
- `materialData[36] -> biMetallicConnector`
- `materialData[37] -> fasteners`
- `materialData[38] -> otherMaterials`

Override behavior:

- each rate can be replaced by `rateOverrides.<sameKey>`
- React falls back to `0.0` when neither an override nor a material rate is present

Conditional inclusion behavior:

- React omits these rate keys entirely when the matching boolean is false:
  - `hvCableBox`
  - `lvCableBox`
  - `hvBushing`
  - `lvBushing`
  - `drainValve`
  - `filterValve`
  - `samplingValve`
  - `oltc`
  - `octc`
  - `oilLevelGauge`
  - `mog`
  - `pressureReliefValve`
  - `rollers`

### Saga normalization behavior

`FileSaga` normalizes the outgoing payload before posting:

- it keeps only the known keys for `lomBooleans`, `lomQuantity`, and `lomRate`
- it defaults `isTrue` to `true` if missing
- it supports a legacy boolean alias:
  - if `lomBooleans.biMetallicConn` is present and `lomBooleans.biMetallicConnector` is absent
  - the saga maps it to `biMetallicConnector`
- it removes conditional rate keys when the paired boolean is explicitly `false`

Important implication for Flutter:

- The request contract is field-name-sensitive and also partially order-dependent because the rate map is built from the ordered `lomMaterial` list.
- Flutter should preserve the exact outgoing keys and the conditional omission behavior.

## Material master data contract

Before generating the LOM, React fetches:

- Method: `POST`
- Endpoint family: `/entity/v2/lomMaterial`
- Query string: `offset=0&size=100&sortAttribute=createdAt&sortOrder=ASC`

Important behavior to preserve:

- The files screen assumes the returned list order is stable.
- The LOM rate mapping is positional, not keyed by a material code or name.

## Reducer-backed state contract

The file reducer initializes:

- `lom`
  - `data`
  - `isLoading`
  - `isFullfilled`
  - `isFailed`
  - `error`
- `customer`
  - `data.customerName`
  - `data.customerPlace`
  - `isLoading`
  - `isFullfilled`
  - `isFailed`
  - `error`

Reducer behavior:

- `FETCH_FILE` sets `lom.isLoading = true`
- `FETCH_FILE_FULFILLED` replaces `lom.data` with the backend response
- `FETCH_FILE_FAILED` stores `error.message`
- `ADD_DATA_TO_LOM` appends a local row to `lom.data`
- `DELETE_DATA_FROM_LOM` removes a local row by table index
- `ADD_CUSTOMER` updates reducer state only
- `RESET_CUSTOMER_DATA` resets customer fields to empty strings

Important implication for Flutter:

- Customer details are local reducer state in the current React implementation.
- They are not persisted through `FileSaga` and are not saved to a dedicated backend endpoint from this screen.

## Screen behavior contract

### Initialization

On mount and relevant state changes, React:

1. fetches `lomMaterial` when the material list is empty and not already loading
2. builds a fresh LOM payload from `twoWindings`, `fabrication`, and material rates
3. posts the payload to `/files/lom`
4. copies `lom.data` into local `tableRows` state, enriching rows with:
   - `index`
   - `isNew`
   - `rateKey`

### Layout

The page is split into:

- a main left document surface
- a right download/export panel

Main sections:

- customer name and customer place header
- search input
- accordion list with:
  - `LOM`
  - `CCC`

Default accordion state:

- `LOM = true`
- `CCC = false`

### LOM table behavior

React renders table rows from `tableRows`.

Loading and empty-state behavior:

- `lom.isLoading` shows `"Loading LOM items..."`
- otherwise an empty list shows `"No LOM items available yet."`

Manual row add behavior:

- the user can add a new row with:
  - `description`
  - `specification`
  - `unit`
  - `quantity`
  - `rate`
- React validates only that these fields are non-empty
- new rows are marked with:
  - `isNew = true`
  - `rateKey = null`
- `cost` is computed as `quantity * rate`
- React dispatches `addDataToLom(newRow)`

Delete behavior:

- React removes the row from local `tableRows`
- React dispatches `deleteDataFromLom(index)`

Rate edit behavior:

- editing an existing backend-derived row updates `rateOverrides[rateKey]`
- the rate override triggers a fresh `/files/lom` request
- editing a manually added row only updates local row cost

### Customer behavior

Customer fields:

- `customerName`
- `customerPlace`

Behavior:

- the screen toggles between read-only and inline edit mode
- save uses `addCustomer({ customerName, customerPlace })`
- this updates file reducer state only

Current limitation in React:

- customer values on this screen are session-local unless some other flow persists them
- this screen does not call a dedicated backend endpoint for customer persistence

### Design save behavior

The `Save this design` action:

1. locates the design record where:
   - `item.designId == twoWindings.data.designId`
2. takes the matched design payload
3. sets:
   - `payload.lom = JSON.stringify(lom.data)`
4. dispatches:
   - `addEntity(payload, "design", true)`

Important behavior to preserve:

- saving the files screen updates an existing design record
- the persisted `lom` field is stored as a JSON string
- this flow does not create a new design record

## PDF and download contract

The files screen exposes document actions for:

- `Des. Prnt Out`
- `GTP`
- `Core Assembly`
- `Core Blade`
- `LOM`
- `Tank`
- `ActivePart`
- `Conservator`
- `Lid`
- `MainAssembly_GAD`
- `Rating Plate`
- `Print All` button is present in the UI

Observed implementation details:

- PDF generation uses `jsPDF` and `jspdf-autotable`
- generated PDFs are opened with `window.open(pdfBlobUrl, "_blank")`
- several download actions directly open hosted files under:
  - `https://transformer.treffertech.com/000_delivery/{designId}/{designId}_Tank_GAD.pdf`
  - `https://transformer.treffertech.com/000_delivery/{designId}/{designId}_ActivePart_GAD.pdf`
  - `https://transformer.treffertech.com/000_delivery/{designId}/{designId}_Conservator.pdf`
  - `https://transformer.treffertech.com/000_delivery/{designId}/{designId}_Lid.pdf`
  - `https://transformer.treffertech.com/000_delivery/{designId}/{designId}_MainAssembly_GAD.pdf`
  - `https://transformer.treffertech.com/000_delivery/{designId}/{designId}_Rating_plate.pdf`

Important implication for Flutter:

- The migration should separate document-generation behavior from core LOM data behavior.
- Some export actions are generated locally, while others are direct hosted-file launches.

## Migration implications

- Model `/files/lom` with typed request objects that preserve exact backend field names.
- Keep the material-rate mapping deterministic and compatible with the current ordered `lomMaterial` list.
- Preserve conditional omission of rate fields when corresponding booleans are false.
- Treat customer header details as local UI state unless product approves a persistence change.
- Persist `lom` back into the design entity as a JSON string when the user saves the design.
- Keep the files feature split across data, application, and presentation layers; the current React screen mixes these responsibilities heavily.
