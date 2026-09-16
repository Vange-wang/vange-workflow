# Changelog

This file records user-visible changes. Unreleased entries are not evidence of a published tag or GitHub Release. Dates will be added only when a release is actually published.

## [Unreleased]

### Added

- Contribution guidance covering issue reports, focused pull requests, validation, and security boundaries.
- A proposed v0.1.0 release-notes draft and pre-release checklist.
- Bug report, feature request, and pull request templates with explicit validation and privacy fields.
- A Quick Start with executable read-only checks, a conceptual lead/developer/QA walkthrough, and entry links in both READMEs.

These maintenance additions were merged through PRs #3, #4, and #5 and are present at `86ea49430b35f16a7dbd7a68bf8cf23755d8522a`. They remain unreleased.

## [0.1.0] - Unreleased draft

Proposed first tagged GitHub release; the repository was public before this draft. The version and date remain subject to maintainer confirmation. This section inventories capabilities already present at commit `36626517050d1f876454a8d8c75fefa4b15fe7ee`; it does not backdate their introduction or claim a release has occurred.

### Added

- Fixed-role project coordination for Codex, with registered task/thread routing, explicit ownership, handoffs, and acceptance gates.
- Project repository structure preview and directory-only initialization.
- Project intake and structure inspection with scan diagnostics.
- Hermes critical-document review with a bounded review-round ledger and no-clobber report handling.
- Structural validation, scenario-contract checks, project-tool tests, mock-Hermes tests, and an opt-in real integration smoke script.
- English and Chinese installation and operations manuals, including the getting-started guidance merged in PR #2.

### Security

- Separately approved sanitized-copy requirements for document review.
- Actual model/provider usage evidence, model fallback rejection, and default-model change detection.
- Secret-sensitive handling boundaries and explicit authorization requirements.
- No-clobber review artifacts, a maximum of three started review invocations per frozen scope, and candidate-only automated gate states.

The existence of these checks is not a claim that they have passed for a release candidate. Consult the [release preparation draft](docs/releases/v0.1.0-draft.md) for evidence still required. Before publishing, reconcile merged Unreleased entries into the confirmed version and assign the actual publication date once.
