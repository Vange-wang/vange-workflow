# Critical Document Gate

Load only for a PRD, Spec, architecture, framework, workflow/process, implementation plan, acceptance matrix, production/security/deployment runbook, canonical source of truth, or a document governing multiple downstream roles.

## Ownership

- Author role: produces a coherent draft.
- Hermes CLI `deepseek-v4-pro`: independent read-only reviewer and final automated verdict.
- Registered Document QA: applies the complete serious-finding batch to the named document; never self-approves.
- Issue manager: owns deferred non-blocking Open Issues.
- Project lead: freezes scope, routes, checks evidence, controls the counter, and requests user confirmation.

## One shared review budget

`MAX_REVIEW_ROUNDS = 3` for the same task + canonical document + frozen scope.

- Round 1 reviews the whole coherent scope and reports all reasonably discoverable material findings together.
- Rounds 2–3 verify serious fixes and affected regressions.
- Edits, retries, new hashes, renamed reports, adapter changes, or new threads do not reset the count.
- A new serious finding after round 1 may trigger rework only with evidence that the revision introduced it or that it was not reasonably discoverable earlier.
- After round 3, unresolved serious findings produce `DOCUMENT_REVIEW_LIMIT_REACHED`; only the user can choose risk acceptance, scope change, or a materially new review cycle.

## Severity contract

`SERIOUS` materially threatens correctness, approved scope, feasibility, security/privacy, irreversible decisions, failure handling, acceptance/testability, or downstream execution.

`NON_SERIOUS` covers wording, style, optional enhancement, or local clarity without material ambiguity. It becomes a named non-blocking Open Issue with a future closure trigger and does not consume QA or review rounds.

Round 1 must not drip-feed issues. Later rounds must not reopen the document for taste-driven polishing.

## Preflight

1. Finish `THINK_BEFORE_ACTING`; review is validation, not outsourced design.
2. Validate the registered Document QA binding and exclusive write scope.
3. Check document classification and project policy; redact secrets and restricted customer data from the temporary copy.
4. Run:

```powershell
pwsh -NoLogo -NoProfile -File <skill-root>\scripts\review_critical_document.ps1 -Mode Preflight
```

Require a usable Hermes CLI, configured DeepSeek endpoint, and no default-model mutation. If the exact runtime/model or safe review copy cannot be proven, set `HERMES_REVIEW_BLOCKED`.

## Review

Freeze the canonical source and run:

```powershell
pwsh -NoLogo -NoProfile -File <skill-root>\scripts\review_critical_document.ps1 `
  -Mode Review `
  -Source <absolute-document-path> `
  -Report <absolute-report-path> `
  -Round <1|2|3>
```

The script copies the document to an isolated temporary directory, invokes only `deepseek-v4-pro` with the file toolset, writes the report, verifies the canonical hash stayed unchanged, and emits metadata. Do not use `--yolo`, broaden toolsets, alter Hermes configuration, or accept fallback-model output.

## QA remediation

When unresolved serious findings exist before round 3:

1. Set `QA_DOCUMENT_REWORK`.
2. Send one packet containing the canonical path/hash, latest report, frozen decisions, exclusive write scope, complete serious batch, current/remaining rounds, and required correction ledger.
3. QA reasons across the whole batch, edits only the named document and its ledger, preserves accepted decisions, records finding -> old/new location -> rationale -> verification, and returns the new hash plus no-unrelated-diff evidence.
4. Send non-serious findings to the Issue manager, not QA.
5. Request a fresh focused Hermes review only after QA returns.

## Exit

Pass only when all apply:

- runtime evidence identifies `deepseek-v4-pro`;
- the report says `PASS_ZERO_ISSUES` or `PASS_WITH_NONBLOCKING_OPEN_ISSUES`;
- unresolved serious findings are zero;
- report and QA ledger match the final source hash;
- deferred non-serious findings have named owners/triggers;
- no unrelated file changed.

Then set `DOCUMENT_GATE_PASSED`, followed by `USER_CONFIRMATION_PENDING`. Present the final document/hash, report, round `n/3`, QA ledger, and Open Issues. Do not start downstream implementation before user confirmation.
