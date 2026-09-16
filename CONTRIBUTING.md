# Contributing to Vange Workflow

Contributions are welcome through focused issues and pull requests. Start with the [README](README.md) or [中文手册](README.cn.md) to understand the project's scope. This is a fixed-role coordination skill, not a standalone agent platform.

## What to contribute

Useful contributions include bug fixes, documentation improvements, workflow improvements, new reviewer adapters, cross-platform support, test coverage, small example projects, and clearer diagnostics. These are contribution areas, not claims that every platform or adapter is already supported.

For changes to permissions, ownership, review contracts, or platform support, discuss the use case and proposed boundaries before implementing a broad change. A replacement reviewer CLI needs its own validated adapter; renaming an executable is insufficient.

## Before opening an issue

- Search [existing issues](https://github.com/Vange-wang/vange-workflow/issues), including closed reports, for the same problem.
- Identify the request as a bug, feature request, or documentation correction.
- Include the repository commit, OS, Codex client/version, PowerShell version, and Hermes CLI/version when relevant. Mark unavailable or irrelevant details explicitly.
- For a bug, provide the smallest synthetic input, exact command or steps, expected behavior, actual behavior, and sanitized logs needed to reproduce it.
- For a feature, describe the user problem, alternatives, affected contracts, permission implications, and observable acceptance criteria.
- Do not disclose credentials or private project material in public issues. If a problem cannot be described safely, ask for an appropriate reporting channel without attaching the sensitive evidence.

## Before opening a pull request

1. Work in a separate branch from current `main`, using a fork if needed.
2. Keep one goal per PR and avoid unrelated formatting, generated output, or runtime changes.
3. Explain the problem, resulting behavior, exact scope, and any compatibility or permission impact.
4. Report commands actually run, results, and checks not run with reasons. An unchecked test is not a pass.
5. Use only synthetic, non-sensitive fixtures. Never commit API keys, tokens, cookies, private keys, local credentials, or unsanitized private documents.
6. Inspect `git diff --check`, the complete diff, and the file list before submission.

The [runtime instructions](SKILL.md) and [review contract](references/critical-document-review.md) govern behavior. Preserve the README's distinction between the installed canonical runtime source and repository packaging; a PR must not silently overwrite an installation or declare a new competing source. Runtime synchronization remains a separate authorized maintainer action.

## Validation by change type

Run commands from the repository root in PowerShell 7. Record the tested commit and environment. The lists below describe requirements; they do not assert that any check has already passed.

### Documentation and templates

```powershell
git diff --check
```

Check relative file links, section anchors, code fences, template fields, and English/Chinese consistency where both languages change. For skill rules, structure descriptions, or release preparation, also run:

```powershell
pwsh -NoLogo -NoProfile -File .\tests\validate_lean_skill.ps1 -Path .
```

There is no packaged general Markdown-link checker; describe your manual or local link checks in the PR. A documentation-only change does not require a paid model call.

### Scripts, workflow behavior, and adapters

Parse affected PowerShell files, run focused regression checks, and run the existing local suite before marking behavior changes ready:

```powershell
pwsh -NoLogo -NoProfile -File .\tests\validate_lean_skill.ps1 -Path .
pwsh -NoLogo -NoProfile -File .\tests\run_scenarios.ps1 -Path .
pwsh -NoLogo -NoProfile -File .\tests\test_project_tools.ps1 -Path .
pwsh -NoLogo -NoProfile -File .\tests\test_review_critical_document.ps1 -Path .
```

`run_scenarios.ps1` checks documented scenario contracts; it does not drive real Codex tasks. `test_project_tools.ps1` exercises directory creation and scanning inside temporary fixtures. `test_review_critical_document.ps1` uses the mock Hermes fixture, not the real review service. Those fixture tests clean up their own temporary directories.

Add meaningful regression coverage for changed behavior. Passing keyword or mock checks cannot establish real integration, platform support, or user acceptance.

### Real Hermes integration

When real integration evidence is required, obtain explicit authorization and use only the generated non-sensitive test text in `tests/run_real_hermes_smoke.ps1`. Do not run it as an automatic prerequisite for every PR. State whether a real API call was made, which commit/environment was tested, and which evidence was obtained; never attach credentials or restricted logs. See [validation and release requirements](README.md#11-validate-the-skill).

A real project-document review still requires a separately approved sanitized copy, the shared three-round ledger, actual model evidence, no-clobber artifacts, and the existing human gates. Synthetic testing does not waive those requirements.

## Security and review standards

Never weaken a safety gate just to make a test pass. In particular, do not bypass actual-model verification, permit silent fallback, reset a consumed review round, overwrite review evidence, or promote a candidate gate to final acceptance automatically.

Reviewers check:

- a clear scope and a concrete reason for the change;
- compatibility with existing contracts and explicit task/role authority;
- one owner per mutable artifact and one canonical source;
- preserved sanitization, model verification, ledger, and no-clobber boundaries;
- adequate, attributable validation evidence and explicit untested cases.

Maintainers may request narrower scope or additional evidence. An accepted PR does not itself prove that a downstream project has completed its acceptance gates.
