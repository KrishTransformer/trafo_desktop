# CAD Job And Live Status Contract

This document defines the proposed backend contract for queued CAD model generation and live step-by-step status updates.

The goal is to replace the current direct-write status pattern with:

1. a queue-backed CAD job model
2. a backend-owned status ingestion path
3. a stable read model for frontend polling and socket updates

## Scope

This contract covers:

- job submission
- duplicate-request handling
- queue position visibility
- job lifecycle state
- step-by-step status updates during CAD execution
- model completion signaling
- socket event payloads

This contract does not require the frontend to know how the queue is implemented internally.

## Core Principles

1. `POST /cad/run-3d-generation` becomes an enqueue operation, not a run-immediately operation.
2. The CAD worker publishes status updates through a backend-owned internal endpoint.
3. Status rows are system-managed records, not user-authored generic entity writes.
4. Every job has a stable `runId`.
5. Every step update is tied to a `runId` and `designId`.
6. Job state and step state are separate concepts.

## Domain Model

### CAD generation job

One record per model-generation request.

Suggested fields:

```json
{
  "runId": "cad_20260729_000123",
  "designId": "500k-72270",
  "requestedBy": "uid-123",
  "requestedAt": "2026-07-29T12:10:00.000Z",
  "startedAt": "2026-07-29T12:10:07.000Z",
  "completedAt": null,
  "jobStatus": "QUEUED",
  "queuePosition": 2,
  "queueName": "cad-3d-default",
  "skipBatRun": false,
  "modelFileName": "500k-72270.glb",
  "failureCode": null,
  "failureMessage": null,
  "latestStepMessage": "Waiting for worker",
  "latestStepStatus": "REQUESTED",
  "statusCount": 1,
  "reusedExistingJob": false
}
```

### CAD generation status step

One record per visible progress step.

Suggested fields:

```json
{
  "runId": "cad_20260729_000123",
  "designId": "500k-72270",
  "sequenceNumber": 1,
  "stepKey": "REQUEST_ACCEPTED",
  "message": "Generate 3D requested",
  "status": "REQUESTED",
  "createdAt": "2026-07-29T12:10:00.000Z",
  "source": "cad-api"
}
```

## Enumerations

### Job status

Allowed values:

- `QUEUED`
- `RUNNING`
- `COMPLETED`
- `FAILED`
- `CANCELLED`

Meaning:

- `QUEUED`: request accepted and waiting for worker capacity
- `RUNNING`: worker started processing the job
- `COMPLETED`: model generation finished successfully and model artifact is expected to exist
- `FAILED`: generation stopped with an error
- `CANCELLED`: job was intentionally stopped before completion

### Step status

Allowed values:

- `REQUESTED`
- `PROCESSING`
- `SUCCESS`
- `FAILED`
- `INFO`

Meaning:

- `REQUESTED`: request was accepted or queued
- `PROCESSING`: current active work is in progress
- `SUCCESS`: a specific step completed successfully
- `FAILED`: a specific step failed
- `INFO`: optional neutral status for non-terminal informational updates

## Public API Contract

### 1. Submit or reuse a CAD job

Endpoint:

- `POST /cad/run-3d-generation`

Behavior:

- validates the request
- checks whether the same `designId` already has a `QUEUED` or `RUNNING` job
- if an active job already exists, returns that job instead of creating a duplicate
- otherwise creates a new job and enqueues it

Request query params:

- `fileName=<designId>`
- `skipBatRun=no|yes`

Request body:

- current flattened fabrication payload can remain as-is for compatibility

Suggested success response:

```json
{
  "runId": "cad_20260729_000123",
  "designId": "500k-72270",
  "jobStatus": "QUEUED",
  "queuePosition": 2,
  "message": "CAD job queued",
  "reusedExistingJob": false
}
```

Suggested duplicate response:

```json
{
  "runId": "cad_20260729_000118",
  "designId": "500k-72270",
  "jobStatus": "RUNNING",
  "queuePosition": 0,
  "message": "Existing CAD job reused",
  "reusedExistingJob": true
}
```

Recommended HTTP status:

- `202 Accepted`

### 2. Read one CAD job

Endpoint:

- `GET /cad/jobs/{runId}`

Purpose:

- lets the frontend read overall queue and job lifecycle state

Suggested response:

```json
{
  "runId": "cad_20260729_000123",
  "designId": "500k-72270",
  "jobStatus": "RUNNING",
  "queuePosition": 0,
  "requestedAt": "2026-07-29T12:10:00.000Z",
  "startedAt": "2026-07-29T12:10:07.000Z",
  "completedAt": null,
  "latestStepMessage": "Building tank model",
  "latestStepStatus": "PROCESSING",
  "statusCount": 7,
  "modelUrl": null,
  "failureCode": null,
  "failureMessage": null
}
```

### 3. Read active job by design

Endpoint:

- `GET /cad/jobs/active?designId={designId}`

Purpose:

- lets the frontend reopen a design and discover whether a queue entry or active run already exists

Suggested response:

```json
{
  "runId": "cad_20260729_000123",
  "designId": "500k-72270",
  "jobStatus": "QUEUED",
  "queuePosition": 2
}
```

Suggested empty response:

```json
{
  "runId": null,
  "designId": "500k-72270",
  "jobStatus": null,
  "queuePosition": null
}
```

### 4. Read status timeline for one job

Endpoint:

- `GET /cad/jobs/{runId}/statuses`

Purpose:

- returns the ordered timeline for the current job only

Suggested response:

```json
{
  "runId": "cad_20260729_000123",
  "designId": "500k-72270",
  "data": [
    {
      "sequenceNumber": 1,
      "stepKey": "REQUEST_ACCEPTED",
      "message": "Generate 3D requested",
      "status": "REQUESTED",
      "createdAt": "2026-07-29T12:10:00.000Z",
      "source": "cad-api"
    },
    {
      "sequenceNumber": 2,
      "stepKey": "QUEUE_STARTED",
      "message": "Worker started processing",
      "status": "PROCESSING",
      "createdAt": "2026-07-29T12:10:07.000Z",
      "source": "cad-worker"
    }
  ],
  "total": 2
}
```

## Internal Write Contract

### 5. Publish a new job step

Endpoint:

- `POST /internal/cad/jobs/{runId}/statuses`

Purpose:

- used only by trusted backend components such as the CAD worker or automator bridge

Authentication:

- service-to-service secret, signed token, or internal network trust
- not an end-user bearer token

Request body:

```json
{
  "designId": "500k-72270",
  "stepKey": "BUILD_TANK_MODEL",
  "message": "Building tank model",
  "status": "PROCESSING",
  "source": "automator",
  "occurredAt": "2026-07-29T12:10:11.000Z"
}
```

Behavior:

- validates `runId`
- verifies that the job is `QUEUED` or `RUNNING`
- assigns the next `sequenceNumber`
- appends a new timeline record
- updates the parent job's `latestStepMessage`, `latestStepStatus`, and `statusCount`
- emits a socket event

Suggested response:

```json
{
  "runId": "cad_20260729_000123",
  "designId": "500k-72270",
  "sequenceNumber": 3,
  "accepted": true
}
```

### 6. Mark job state transitions

The worker or orchestration layer should update job state at these points:

1. after enqueue: `QUEUED`
2. when a worker starts the job: `RUNNING`
3. when the GLB is confirmed written: `COMPLETED`
4. when generation aborts: `FAILED`
5. when an operator or future UI stops the job: `CANCELLED`

Terminal updates should always create a matching status step.

Example terminal success step:

```json
{
  "stepKey": "PROCESS_FINISHED",
  "message": "Process finished!",
  "status": "SUCCESS"
}
```

Example terminal failure step:

```json
{
  "stepKey": "PROCESS_FAILED",
  "message": "Model generation failed during tank assembly",
  "status": "FAILED"
}
```

## Socket Event Contract

The frontend can keep polling as a fallback, but sockets should become the primary live-update path.

### Event: `cad.job.updated`

Purpose:

- coarse-grained job lifecycle and queue updates

Payload:

```json
{
  "runId": "cad_20260729_000123",
  "designId": "500k-72270",
  "jobStatus": "RUNNING",
  "queuePosition": 0,
  "latestStepMessage": "Building tank model",
  "latestStepStatus": "PROCESSING",
  "updatedAt": "2026-07-29T12:10:11.000Z"
}
```

### Event: `cad.job.status.created`

Purpose:

- append one new timeline item to the UI without refetching the full list

Payload:

```json
{
  "runId": "cad_20260729_000123",
  "designId": "500k-72270",
  "sequenceNumber": 3,
  "stepKey": "BUILD_TANK_MODEL",
  "message": "Building tank model",
  "status": "PROCESSING",
  "createdAt": "2026-07-29T12:10:11.000Z",
  "source": "automator"
}
```

### Event routing recommendation

Socket subscriptions should be scoped by at least one of:

- `runId`
- `designId`

This avoids pushing unrelated CAD traffic to every connected client.

## Duplicate Request Rules

For the initial version:

1. if the same `designId` already has a `QUEUED` job, return the existing job
2. if the same `designId` already has a `RUNNING` job, return the existing job
3. only create a new job when the latest active job is terminal

Optional future extension:

- add `forceRestart=true` for explicit operator-driven requeue behavior

## Ordering Rules

1. Job queue order should be FIFO by `requestedAt`
2. Status step order should be by `sequenceNumber`
3. `createdAt` should be stored in UTC ISO-8601 format

The frontend should use `sequenceNumber` as the primary ordering signal and `createdAt` as a display field.

## Backward Compatibility Notes

To reduce migration risk:

1. the frontend can continue sending the current flattened fabrication payload
2. the frontend can switch from generic `drawingsStatus` polling to `GET /cad/jobs/{runId}/statuses`
3. the old generic entity path can remain temporarily for read-only fallback during rollout

During migration, the frontend should stop:

- deleting generic `drawingsStatus` rows before every run
- writing the first status row itself

Those responsibilities move to backend orchestration.

## Recommended Initial Implementation Shape

Use two persisted collections or equivalents:

1. `cadGenerationJob`
2. `cadGenerationStatus`

Suggested relationship:

- one `cadGenerationJob`
- many `cadGenerationStatus`

If `drawingsStatus` must be reused temporarily, add at least:

- `runId`
- `sequenceNumber`
- `stepKey`
- `source`

But the cleaner long-term design is a dedicated job-status model.

## Open Implementation Notes

1. The CAD service source is not present in this workspace, so this contract identifies the intended boundary but not the concrete implementation class.
2. `tf-common-service` should not remain the direct external writer target for background CAD step events.
3. The current React rule that treats `"Generate 3D Requested"` as `status = "Success"` should be removed during integration with this contract.
