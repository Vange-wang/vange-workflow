# Critical Document Gate

Load only for a PRD, Spec, architecture, framework, workflow/process, implementation plan, acceptance matrix, production/security/deployment runbook, canonical source of truth, or a document governing multiple downstream roles.

## Ownership and reviewer policy

- Author role: produces a coherent draft and freezes the canonical source.
- Sanitization owner: creates a separate review copy, removes secrets and restricted data, and records who approved it. The review script never sanitizes or claims that an unapproved copy is safe.
- Reviewer CLI: performs read-only independent review. Hermes CLI with `deepseek-v4-pro` is the recommended default.
- Registered Document QA: applies one complete serious-finding batch to the named document; never self-approves.
- Issue manager: owns deferred non-blocking Open Issues.
- Project lead: freezes scope, routes work, checks evidence, and controls final gates without writing specialist deliverables.

An alternative CLI model requires explicit user approval plus a recorded capability basis showing it is not materially weaker than the product manager, project lead, and independent QA. The usage report must identify the requested model as the actual runtime model; any silent fallback blocks the review.

The packaged PowerShell script is specifically the Hermes CLI adapter. Another user-approved reviewer CLI requires its own adapter that preserves the same sanitized-copy isolation, source-hash checks, actual model/provider evidence, fallback rejection, append-only shared round ledger, no-clobber artifacts, report schema, and candidate-only gate semantics. Renaming an executable or dropping evidence is not an equivalent substitution.

A desktop controller must not download or install a reviewer CLI without explicit user approval. If no CLI can be used, request authorization for a separate independent review task in the controller; do not create it implicitly and do not replace review with self-approval.

## One shared review budget

`MAX_REVIEW_ROUNDS = 3` for the same task + canonical document + frozen scope.

- The script derives one append-only JSONL ledger from `TaskId`, canonical path, `ScopeId`, and `Hermes_handoff`.
- A `review_started` event consumes a round even when the invocation, model proof, or report validation later fails. Retries do not reset the counter.
- Round 1 reviews the whole coherent scope and reports all reasonably discoverable material findings together.
- Rounds 2–3 verify serious fixes and affected regressions.
- Edits, new hashes, renamed reports, model adapters, or thread changes do not reset the count.
- A new serious finding after round 1 may trigger rework only with evidence that the revision introduced it or that it was not reasonably discoverable earlier.
- After round 3, unresolved serious findings produce `DOCUMENT_REVIEW_LIMIT_REACHED`; only the user can accept named risk, change scope, or authorize a materially new cycle.

## Severity contract

`SERIOUS` materially threatens correctness, approved scope, feasibility, security/privacy, irreversible decisions, failure handling, acceptance/testability, or downstream execution.

`NON_SERIOUS` covers wording, style, optional enhancement, or local clarity without material ambiguity. It becomes a named non-blocking Open Issue with a future closure trigger and does not cause document rework.

## Preflight

1. Finish `THINK_BEFORE_ACTING`; review validates a coherent draft rather than outsourcing design.
2. Freeze the canonical source and record its SHA-256, bytes, lines, task ID, and frozen scope ID.
3. Create `协同工作文档/Hermes_handoff`, produce a separate sanitized copy there, and obtain a named sanitization approval. Never pass the canonical source as the review copy.
4. Resolve the Document QA binding if available. A missing QA binding does not spend or block round 1, but any serious finding remains `QA_DOCUMENT_REWORK`-blocked until the user authorizes a valid separate owner.
5. Run:

```powershell
pwsh -NoLogo -NoProfile -File <skill-root>\scripts\review_critical_document.ps1 `
  -Mode Preflight `
  -ReviewModel deepseek-v4-pro
```

Preflight must prove a usable CLI and `--usage-file` support. It reports only a default-model snapshot; unchanged-default proof is produced by comparing snapshots before and after a real review.

Before spending a real project round, run the packaged real-Hermes smoke with its generated non-sensitive fixture. If a desktop/Codex sandbox blocks Hermes child processes, the controller must request user approval for local execution before retrying the same smoke or review command; it must not silently weaken the sandbox or launch parallel model calls.

For an approved alternative model, also pass `-AlternativeModelApprovedBy <approval>` and `-CapabilityBasis <comparison>`.

## Review

Use a new report filename for every invocation:

```powershell
pwsh -NoLogo -NoProfile -File <skill-root>\scripts\review_critical_document.ps1 `
  -Mode Review `
  -Source <absolute-canonical-document-path> `
  -ReviewCopy <absolute-approved-sanitized-copy-path> `
  -HandoffDirectory <absolute-Hermes_handoff-path> `
  -Report <absolute-new-round-report-path> `
  -TaskId <stable-task-id> `
  -ScopeId <stable-frozen-scope-id> `
  -SanitizationApprovedBy <named-approver-or-approval-id> `
  -Round <1|2|3> `
  -ReviewModel deepseek-v4-pro `
  -ReviewTimeoutSeconds 600
```

The timeout defaults to 600 seconds and may be set from 30–3600 seconds; a timeout still consumes the started round. The script rejects path collisions, existing report/metadata/rejected-output files, reparse points anywhere in protected paths, missing sanitization attestation, round reuse, ledger mismatch, invalid report schema, model fallback, default-model mutation, and any change to the canonical or review copy. Invalid reviewer stdout is retained only as a no-clobber `.rejected.md` diagnostic artifact and is never promoted to the formal report. Hermes runs in an isolated temporary directory with only the approved copy, `file` tools, and no project rules/memory injection.

Successful execution emits:

- `HERMES_INVOCATION_PASS`: the CLI call completed;
- `HERMES_REPORT_VALIDATED`: usage evidence and report schema are valid;
- `QA_DOCUMENT_REWORK`, `DOCUMENT_REVIEW_LIMIT_REACHED`, or `DOCUMENT_GATE_CANDIDATE`.

`DOCUMENT_GATE_CANDIDATE` is not final approval. The lead must still verify Issue ownership, applicable QA evidence, unchanged hashes, and user confirmation.

## QA remediation

When unresolved serious findings exist before round 3:

1. Set `QA_DOCUMENT_REWORK`.
2. Send one packet containing the canonical path/hash, latest report, frozen decisions, exclusive write scope, complete serious batch, current/remaining rounds, and required correction ledger.
3. QA edits only the named document and its ledger, records finding -> old/new location -> rationale -> verification, and returns the new hash plus no-unrelated-diff evidence.
4. Send non-serious findings to the Issue manager, not QA.
5. Request the next focused review only after QA returns; use the same task/scope IDs and handoff directory.

## Exit

Set `DOCUMENT_GATE_PASSED` only when all applicable conditions hold:

- usage evidence identifies the approved actual runtime model;
- the report says `PASS_ZERO_ISSUES` or `PASS_WITH_NONBLOCKING_OPEN_ISSUES`;
- unresolved serious findings are zero;
- report/metadata/ledger match the final source hash;
- when QA remediation occurred, the QA ledger matches the final source hash and QA did not self-approve;
- when non-serious findings exist, each has a named Open Issue owner and closure trigger;
- no unrelated file changed.

Then set `USER_CONFIRMATION_PENDING`. Present the final document/hash, report, round `n/3`, applicable QA ledger, and Open Issues. Do not start downstream implementation before user confirmation.
