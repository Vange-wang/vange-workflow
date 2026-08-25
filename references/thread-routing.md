# Registered Role Routing

Load before messaging, rebinding, or resolving fixed project-role threads/tasks/sessions.

## Resolve the route

Use current evidence in this order:

1. nearest `AGENTS.md`;
2. canonical role registry;
3. role anchor and append-only work log;
4. active task, Spec, milestone, or Issue;
5. continuity/relay packet;
6. live thread state.

Memory, titles, and historical IDs are hints, not authority. Prefer the latest explicit active binding and preserve old IDs as archive-only.

A valid route identifies:

- canonical role and live thread ID/title/status;
- authoritative inputs and owned outputs;
- exact write and forbidden scopes;
- role anchor/work log;
- upstream and downstream gates.

Missing fields produce `REGISTRY_INCOMPLETE`; do not guess.

## Validate live

When thread tools exist:

1. list/search by returned ID or exact title;
2. read current status;
3. confirm ID, title, project, role, and binding agree with project records;
4. reject archived, missing, mismatched, or superseded targets;
5. do not change model/reasoning settings without explicit user instruction.

Message an existing registered thread only when the current task explicitly authorizes registered-role collaboration. Creating, forking, archiving, renaming, or pinning a user-owned thread requires an explicit request. A subagent requires separate explicit authorization.

## Dispatch

- One bounded role task per message.
- Send exact paths, frozen decisions, write scope, forbidden actions, acceptance checks, and required return shape.
- Omit unrelated lead-thread history.
- Assign one owner per mutable artifact.
- Send downstream work only after the upstream gate passes.
- Parallelize only independent tasks with disjoint writes and no pending dependency.

The lead may inspect evidence, maintain authorized status records, prepare the next packet, and follow up in the same thread. It must not duplicate specialist work or treat silence as permission to take over.

## Rework and review

- Ordinary defect -> return a bounded `REWORK_REQUIRED` packet to the original owner.
- Critical document -> Hermes reviews; registered Document QA edits only the named document's complete serious batch; Issue manager owns non-serious findings.
- Producer reruns targeted and affected regression checks.
- Independent reviewer issues the verdict.
- Issue manager changes Issue state only with required evidence and acceptance.
- Lead aggregates and routes; it does not impersonate these roles.

## Failure states

| State | Required response |
| --- | --- |
| `ROLE_THREAD_UNAVAILABLE` | Record the registration gap and request minimum registration/authorization; lead does not substitute. |
| `REGISTRY_INCOMPLETE` | Stop dispatch; repair records only when authorized. |
| `THREAD_BINDING_MISMATCH` | Preserve state and request rebind confirmation. |
| `ROLE_BOUNDARY_BLOCKED` | Return without mutation and identify the correct owner. |
| `WRITE_SCOPE_CONFLICT` | Sequence work or assign one owner. |
| `UPSTREAM_GATE_BLOCKED` | Keep downstream waiting and obtain the prerequisite. |
| `HERMES_REVIEW_BLOCKED` | Preserve the source; do not substitute model or expose restricted data. |
| `QA_DOCUMENT_REWORK` | Route one complete serious batch with exclusive scope. |
| `DOCUMENT_REVIEW_LIMIT_REACHED` | Stop automated review after round 3 and request user decision. |
| `SESSION_RELAY_REQUIRED` | Update the relay packet and resume the preserved next action. |

None means completion.

## Continuity and registry maintenance

Before compaction or migration, record completed gates/evidence, immutable constraints, active role IDs, unfinished work/Open Issues, blockers/resume triggers, and one next action. The continuation stays in the same role and resumes without asking the user to repeat documented context.

Keep ID history append-only. Update canonical registry, anchor, and log consistently only with authorization; one role never edits another role's binding.
