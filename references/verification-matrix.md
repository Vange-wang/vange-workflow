# Verification Matrix

Load this reference when selecting evidence for implementation, review, automation, media, installation, or production readiness.

## General order

Run checks from cheap and specific to broad and expensive:

1. existence and parse checks;
2. targeted behavior check;
3. static or local quality gates;
4. integrated build or full-flow check;
5. external environment or human acceptance.

After a rework, repeat both the targeted check and the relevant earlier full checks. A changed defect location does not prove the full artifact remains sound.

## Evidence by deliverable

| Deliverable | Minimum evidence | Higher-risk evidence |
| --- | --- | --- |
| Markdown or coordination docs | reread UTF-8, headings/fields present, paths and IDs valid, no duplicate canonical entry | cross-document consistency, Git diff limited to authorized docs |
| Critical PRD/Spec/framework/workflow/architecture document | decision-readiness record, canonical source hash, separately approved sanitized copy, CLI usage evidence for the approved actual model, append-only review count `n/3`, validated report schema, zero unresolved serious findings | focused fresh review after serious-finding QA edits, named non-blocking Open Issues, no unrelated diff, final user confirmation before downstream execution |
| DOCX/PDF | file opens, text/content check, render to images or PDF, inspect representative pages | inspect every page, font/layout overflow, links and tables |
| Frontend/code | focused test, typecheck, lint where relevant | full tests, build, route/browser smoke, mobile and desktop states |
| Backend/API | focused unit/integration test, schema and error-path check | real service probe, auth/permission tests, load or retry behavior |
| Automation/data job | controlled input, expected output, structured log, nonzero failure on hard errors | rerun behavior, fallback path, rate limits, partial-source handling, idempotency |
| Video/media | project parses/typechecks, render succeeds, duration/resolution/codec check | sampled and defect-range frames, subtitles/audio sync, full playback, old-problem regression scan |
| Local install/config | source and destination check, checksum when published, executable version | actual behavior test, shortcut/association check, restart persistence |
| Deployment/production | local preflight clearly labeled | deployed URL, real environment config, smoke flow, monitoring, rollback evidence |

## Risk-based additions

- Authentication, privacy, payments, minors, deletion, and permissions: test denial paths and fail-closed behavior.
- External UI automation: use dry-run or zero-click probes before assisted single actions; cap actions and preserve an audit log.
- Generated outputs: retain inputs, command, output path, timestamp, and failure reason.
- Critical documents: reject an unapproved review copy, path/report overwrite, silent model fallback, hard-coded model evidence, stale reports, QA self-approval, review of a different hash, an implicit fourth review, review-count reset after edits, issue drip-feeding, taste-driven QA loops, or downstream implementation before `USER_CONFIRMATION_PENDING` is resolved.
- Time-sensitive research: verify live sources and attach source dates; label weaker items for secondary verification.
- Visual fixes: inspect the exact defect range and the whole artifact at a lower sampling density.

## Evidence quality

Strong evidence is reproducible and tied to the current state:

- exact command and exit status;
- test counts or named checks;
- artifact path and checksum, duration, dimensions, or version;
- branch/commit and push/deploy state when relevant;
- screenshot, frame, route response, or structured log;
- named residual risk when a layer remains unverified.

Do not treat plans, prose, stale screenshots, or unpushed local documents as proof of current remote or production state.
