# Workflow State Compatibility

Load when updating a ledger, handling a blocker or migration, pausing, or deciding completion. Preserve these names for existing project compatibility.

## States

| State | Meaning and next action |
| --- | --- |
| `WORKFLOW_ACTIVE` | Objective started; execute the next legal in-scope action. |
| `CONTINUE_TRACKING` | An intermediate gate passed; route the next dependency immediately. |
| `WAITING_ROLE` | A registered owner is working; inspect/follow up in the same thread without substituting. |
| `HERMES_REVIEW_PENDING` | Freeze/hash/sanitize the critical document and run the verified review. |
| `HERMES_REVIEW_BLOCKED` | Exact model/runtime or safe copy is unavailable; preserve source and request minimum unblock action. |
| `QA_DOCUMENT_REWORK` | Route the complete serious-finding batch to registered Document QA before round 3. |
| `DOCUMENT_REVIEW_LIMIT_REACHED` | Round 3 still has a serious finding; stop automated review and request user decision. |
| `DOCUMENT_GATE_CANDIDATE` | CLI usage and report schema passed with zero serious findings; lead still verifies applicable QA, Issue, hash, and no-unrelated-diff evidence. |
| `DOCUMENT_GATE_PASSED` | Final reviewed hash has zero serious findings and complete QA/Issue evidence; request user confirmation. |
| `USER_CONFIRMATION_PENDING` | Present final document/hash/report/ledger; downstream implementation waits. |
| `REWORK_REQUIRED` | Return the defect to its owner and rerun affected checks. |
| `ACCEPTANCE_PENDING` | Artifact exists but an independent or user gate remains. |
| `UPSTREAM_GATE_BLOCKED` | Hold downstream work and obtain the missing prerequisite. |
| `EXTERNAL_BLOCKED` | Preserve state; request minimum credential/authority/external input and resume on trigger. |
| `ROLE_BOUNDARY_BLOCKED` | Perform no mutation; route to the correct registered owner. |
| `ROLE_THREAD_UNAVAILABLE` | Record the missing/invalid binding; request minimum registration or authorization. |
| `SESSION_RELAY_REQUIRED` | Update continuity and resume the preserved next action in the same role. |
| `USER_PAUSED` | User explicitly paused/stopped; preserve state and wait for explicit resume. |
| `WORKFLOW_COMPLETE` | Every applicable artifact, verification, independent review, blocking-Issue closure, and user/Boss gate passed. |

Explicit cancellation is distinct from successful completion.

## Transition rules

- Any active state may enter `SESSION_RELAY_REQUIRED`, then return to its preserved state.
- Only explicit user stop/pause/cancel permits `USER_PAUSED` or cancellation.
- A role/phase return, plan, Spec, local test, build, conditional pass, blocker, timeout, correction, context compaction, or tool failure is non-terminal.
- After rework, rerun targeted checks and affected regression gates.
- `WORKFLOW_COMPLETE` is legal only when the ledger has no unknown or failed applicable gate and names any residual non-blocking risk/owner.

For a critical document:

```text
HERMES_REVIEW_PENDING
  -> QA_DOCUMENT_REWORK -> HERMES_REVIEW_PENDING (while total rounds < 3)
  -> DOCUMENT_REVIEW_LIMIT_REACHED (serious finding after round 3)
  -> DOCUMENT_GATE_CANDIDATE -> DOCUMENT_GATE_PASSED
  -> USER_CONFIRMATION_PENDING
```

No state, hash, retry, adapter, report name, or thread change resets the shared review counter.
