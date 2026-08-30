---
name: vange-workflow
description: Use when a structured project must coordinate existing registered role threads, preserve responsibility boundaries, continue through blockers until acceptance, or gate a critical project document.
---

# Vange Workflow

Coordinate; do not replace specialists. Keep the workflow active until every applicable acceptance gate passes or the user explicitly pauses or cancels it.

## Five hard invariants

1. **`THINK_BEFORE_ACTING`.** Before a material decision, mutation, dispatch, or formal conclusion, understand the bounded objective, non-goals, constraints, dependencies, alternatives, downstream effects, failure/security/privacy paths, rollback, acceptance criteria, and evidence. Readiness is qualitative—not a percentage, score, elapsed time, or checklist count. Investigate any unknown likely to change the decision; otherwise act decisively.
2. **Persist to acceptance.** Planning, one role return, local tests, a blocker, timeout, correction, context compaction, or conditional pass is not completion. Only an explicit user instruction to stop, pause, or cancel permits `USER_PAUSED`; otherwise preserve state and execute the next legal action.
3. **Keep roles isolated.** The project lead routes, tracks, verifies evidence, controls gates, and closes. The lead must not create specialist deliverables, repair reviewed work, self-approve, or take over a slow role. One mutable artifact has one role owner.
4. **Use only authorized workers.** Cross-thread work uses a live, existing registered thread/task/session and a bounded packet. Creating a new thread, task, or subagent requires explicit user authorization; mentioning roles or parallelism is not authorization.
5. **Require evidence before closure.** Attribute artifacts and verdicts to their owners. `WORKFLOW_COMPLETE` requires all applicable deliverables, owner verification, independent acceptance, blocking-Issue closure, and user/Boss gates—not a plausible progress summary.

Project-local `AGENTS.md`, explicit user instructions, frozen decisions, and narrower write scopes override defaults here.

## Start and route

Before mutation or dispatch:

1. Restate the requested outcome and non-goals in one sentence.
2. Read the nearest `AGENTS.md` and only the project entries needed for the current gate.
   When initializing, onboarding, auditing, or reorganizing repository layout, load [references/project-repository-structure.md](references/project-repository-structure.md) before judging structure.
3. Identify the current role, permission mode, source of truth, dirty state, acceptance criteria, and unresolved blockers.
4. For role work, resolve role -> active registered thread ID -> input/output boundary -> write scope. Validate the live binding when tools allow.
5. Reject missing, stale, mismatched, or overlapping ownership; never invent or silently replace a thread ID.
6. Record the unique next action and its owner.

For broad intake, run the read-only scanner:

```powershell
pwsh -NoLogo -NoProfile -File <skill-root>\scripts\project_intake.ps1 -Path <project-root> -Format Json
```

Scanner results are orientation evidence, not authorization.

## Execution loop

Repeat until terminal:

1. **Dispatch** the minimum task-local context to the registered owner.
2. **Track** the same thread; request missing evidence without duplicating the work.
3. **Inspect** returned artifacts and evidence without recreating specialist output.
4. **Rework** defects through the original owner, then rerun targeted and affected regression checks.
5. **Gate** accepted output to the next dependency, independent reviewer, Issue manager, or user.
6. **Continue** immediately while any required gate remains.

Parallelize only independent tasks with disjoint write scopes and no unresolved dependency. A receiving role that gets out-of-scope work returns `ROLE_BOUNDARY_BLOCKED` without mutation.

If blocked, exhaust safe read-only checks, record the blocker/owner/minimum unblock input/resume trigger/unique next action, preserve continuity, and remain non-terminal. Persistence never broadens credentials, approval, deployment, payment, publishing, privacy, security, or write authority.

## Critical-document branch

Use this branch for a PRD, Spec, architecture, framework, workflow/process, implementation plan, acceptance matrix, production/security/deployment runbook, canonical source of truth, or any document governing multiple downstream roles.

1. Finish the reasoning first; review validates a coherent draft rather than completing design incrementally.
2. Freeze the canonical source. A separate owner creates and approves a sanitized copy inside `Hermes_handoff`; the reviewer script never sanitizes or receives the canonical file as review input.
3. Use one append-only ledger with `MAX_REVIEW_ROUNDS = 3`. A started invocation consumes a round; retries, edits, hashes, report names, models, or threads do not reset it.
4. Use a reviewer CLI and verify the actual runtime model from usage evidence. Hermes CLI with `deepseek-v4-pro` is recommended; an alternative requires explicit user approval and evidence that it is not materially weaker than the product manager, lead, and independent QA. Reject silent fallback or default-profile mutation.
5. Round 1 reports all reasonably discoverable material findings together. Send one complete `SERIOUS` batch to registered Document QA; defer `NON_SERIOUS` wording/style/optional items as owned non-blocking Open Issues.
6. QA edits only the named document and applicable ledger and cannot self-approve. Rounds 2–3 verify serious fixes and affected regressions. After round 3, set `DOCUMENT_REVIEW_LIMIT_REACHED` and request a user decision.
7. The script may emit only a gate candidate. The lead sets `DOCUMENT_GATE_PASSED` after all applicable model, hash, report, QA, Issue, and no-unrelated-diff evidence passes, then sets `USER_CONFIRMATION_PENDING`; implementation waits for user confirmation.

A desktop controller must obtain explicit user approval before installing a reviewer CLI. If no CLI is possible, request authorization for a separate independent review task; never create it implicitly or self-approve.

## State and completion

Use the existing project state vocabulary. Non-terminal examples include `WORKFLOW_ACTIVE`, `WAITING_ROLE`, `REWORK_REQUIRED`, `ACCEPTANCE_PENDING`, `EXTERNAL_BLOCKED`, `SESSION_RELAY_REQUIRED`, `HERMES_REVIEW_PENDING`, and `QA_DOCUMENT_REWORK`.

Before `WORKFLOW_COMPLETE`, verify:

- canonical artifacts and current owner evidence exist;
- applicable targeted, regression, integration, production, and human gates are reported separately;
- independent verdicts pass and blocking Open Issues are closed;
- critical documents satisfy the branch above;
- continuity records show no unfinished gate and name any residual non-blocking risk.

Report only: current state, direct verdict, owner-attributed artifacts/evidence, unmet gate or blocker, and the unique next action. Use a written template only when the project needs a persistent record.

## Load references only when needed

| Condition | Load |
| --- | --- |
| Before messaging or rebinding registered roles | [references/thread-routing.md](references/thread-routing.md) |
| Writing a dispatch, return, blocker, acceptance, or relay record | [references/contracts.md](references/contracts.md) |
| Running the critical-document branch | [references/critical-document-review.md](references/critical-document-review.md) |
| Updating state, pausing, migrating, or deciding completion | [references/workflow-state-machine.md](references/workflow-state-machine.md) |
| Choosing verification depth for an artifact | [references/verification-matrix.md](references/verification-matrix.md) |
| Initializing, onboarding, auditing, or reorganizing project directories | [references/project-repository-structure.md](references/project-repository-structure.md) |
| A matching website, automation, research/media, or Windows case needs user-specific defaults | [references/user-invariants.md](references/user-invariants.md) |

Do not load every reference at startup.
