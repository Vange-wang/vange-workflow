# Conditional Project Defaults

Load only the matching domain section when project-local rules do not already decide the point. The five hard invariants in `SKILL.md` remain universal; do not duplicate them into project records.

## Website and product delivery

- Freeze the minimum closed loop, non-goals, data/state rules, denial paths, and acceptance criteria before implementation.
- Treat privacy, contact exposure, authentication/authorization, payments, deletion, and minors' safety as fail-closed risks.
- Select relevant typecheck, lint, focused tests, build, browser/route smoke, and mobile/desktop checks.
- Report branch/commit/push, deployment environment, production smoke, monitoring, rollback, and user acceptance separately.

## Automation and business agents

- Prefer inspectable fail-closed behavior: probe/dry-run, action caps, structured logs, retries, idempotency, and explicit partial-source handling.
- Distinguish local MVP acceptance from real-service or production acceptance.
- Never hide missing credentials, unavailable sources, or unverified external integration.

## Research and fixed-count selection

- Prefer current primary/high-trust evidence and record source dates.
- Deliver the requested count completely when supportable.
- Stop broadening once evidence is sufficient; label weaker candidates `需二次核验`.
- Do not cross from research/selection into product approval or downstream production unless the current role owns it.

## Short-video and media

- Preserve the approved topic and role boundaries.
- Use natural Chinese narration; on-screen text complements rather than copies the voiceover.
- Track elapsed time, available token/model split, render/rework count, duration, resolution, codec, subtitle/audio sync, representative frames, and affected regression.
- Sanitize recorded UI, raw prompts, private sessions, credentials, and sensitive paths.

## Windows action and installation

- Act on the exact named path or drive; use conservative reversible steps and verify actual artifact/package state.
- For secrets, distinguish secure storage from auto-loading and verify redaction without exposing values.
- Installing software, changing global defaults, or changing security/privacy settings requires the applicable explicit approval.
