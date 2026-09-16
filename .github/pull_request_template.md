## Summary

Describe the concrete change. Link an existing issue if relevant; creating an issue solely for a PR is not required.

## Scope

List changed files or areas and explicitly excluded areas. Keep this PR focused on one goal.

## Why

Explain the problem and why this change is needed.

## Behavior changes

Does runtime behavior change? Describe before/after behavior and effects on ownership, permissions, review contracts, or compatibility. For documentation-only work, say so explicitly.

## Validation

Check a box only if you actually ran that check. Provide the exact command, tested commit/environment, result, and relevant evidence. Mark unrun or inapplicable checks with a reason; they are not passes.

- [ ] `git diff --check`
- [ ] Markdown links, anchors, and template fields checked
- [ ] `pwsh -NoLogo -NoProfile -File .\tests\validate_lean_skill.ps1 -Path .`
- [ ] `pwsh -NoLogo -NoProfile -File .\tests\run_scenarios.ps1 -Path .`
- [ ] `pwsh -NoLogo -NoProfile -File .\tests\test_project_tools.ps1 -Path .`
- [ ] `pwsh -NoLogo -NoProfile -File .\tests\test_review_critical_document.ps1 -Path .` (mock Hermes)
- [ ] Real Hermes smoke test — only check after an explicitly authorized real call using generated non-sensitive text; include command and result

Do not run a paid or real API test merely to fill a checkbox. Local or mock passes do not imply real integration or final user acceptance.

## Security checklist

- [ ] No secrets added
- [ ] No unsanitized private documents or sensitive fixtures added
- [ ] Existing review and authorization boundaries are preserved
- [ ] No silent fallback is introduced and actual-model verification is preserved
- [ ] Review-round limits and no-clobber evidence handling are preserved

## Notes

State remaining risks, tests not run and why, unmet gates, and follow-up work. Do not claim release readiness or adoption without evidence.
