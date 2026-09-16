# Vange Workflow

**English** | [简体中文](README.cn.md)

Vange Workflow is a fixed-role project coordination skill for Codex and Hermes CLI.

It helps a project lead route work to registered specialist tasks, track handoffs, check evidence, and manage acceptance gates while specialists own their deliverables. It addresses unclear ownership, missed handoffs, missing evidence, and premature completion claims in multi-task AI-assisted projects. It is not intended for one-off questions or simple work handled by a single agent.

- **Client capabilities:** this is not a standalone general-purpose multi-agent platform. It depends on a Codex client with the required task-management tools; installing the skill does not add missing tools.
- **Authorization:** installation does not authorize new role tasks, forks, subagents, or background agents. Use valid registered tasks; creating new ones requires explicit user authorization.

**Regular coordination:** confirm goals and authority → validate registered roles → dispatch work → collect artifacts and evidence → rework or hand off → pass all applicable gates and user acceptance.

**Critical-document branch, when required before downstream implementation:** freeze scope → separately approved sanitized copy → Hermes review → Document QA remediation and re-review if needed → gate approval and user confirmation → downstream implementation. Script output is only a gate candidate; see [review rules and the three-round limit](#7-critical-documents-hermes-and-document-qa).

## Getting started

1. **Check the environment and permissions.** You need a Codex client with the required task-management capabilities and PowerShell 7. The default review setup uses Hermes CLI, a configured DeepSeek API, and the recommended `deepseek-v4-pro` model. Read [dependencies](#32-required-environment) and the [adapter boundary](#33-adapter-boundary-for-alternative-reviewer-clis): an approved alternative CLI needs its own validated adapter.
2. **Install or inspect the existing installation.** Use the [installation command](#31-install-the-skill) only if the target directory does not exist; otherwise inspect local changes before updating. Reopen the Codex task after installation. Before running the relative script commands below, enter the skill root with `Set-Location "$HOME\.codex\skills\vange-workflow"` (adjust this path for a custom installation).
3. **Try a read-only entry point.** Choose an existing test directory you are authorized to inspect. In [directory preview](#43-preview-and-initialize-directories), use only `initialize_project_structure.ps1 -Mode Plan` to list proposed directories; or use [project scanning](#44-audit-an-existing-project) with `project_intake.ps1` to inspect structure and scan diagnostics. Replace `<project-root>` in those examples with the quoted absolute path to your test directory.

These entry points are a preview or scan, not a full multi-role demonstration, completed environment setup, or final acceptance. They do not require `Apply`, a real review API call, role creation, or production deployment.

## Documentation

- [Installation and dependencies](#3-installation-and-dependencies) · [Role registration and routing](#5-fixed-codex-tasks-and-thread-ids)
- [Critical-document review](#7-critical-documents-hermes-and-document-qa) · [Acceptance](#9-acceptance-and-completion)
- [Validation](#11-validate-the-skill) · [Publishing updates](#12-publish-an-update)
- [Runtime instructions](SKILL.md) · [Project structure specification](references/project-repository-structure.md) · [Thread routing contract](references/thread-routing.md)

The currently installed `vange-workflow` skill is the canonical runtime source for this repository. See [SKILL.md](SKILL.md) for runtime instructions. This README is the complete installation and operations manual and is not loaded in full every time the skill runs.

## 1. Core principles

1. **Think fully before acting.** Readiness is a qualitative judgment, not a percentage, elapsed time, or checklist count. Clarify the goal, non-goals, dependencies, failure paths, permissions, rollback, and acceptance before execution.
2. **The project lead does not substitute for specialists.** The lead routes, follows up, checks evidence, maintains state, controls gates, and closes the workflow. The lead does not write specialist deliverables, fix work on behalf of a slow role, or self-review and self-approve.
3. **One mutable artifact has one owner.** Two tasks must not modify the same file or canonical source at the same time.
4. **Use registered tasks only.** Cross-task collaboration must use an existing, valid, registered Codex task ID. Creating a task, fork, subagent, or background agent requires explicit user authorization.
5. **Do not stop before acceptance.** A completed plan, passing local tests, one role returning, a timeout, a blocker, or a conditional pass does not mean the project is complete.
6. **Keep evidence layers separate.** Local, integration, production, independent-review, and user/Boss acceptance evidence must be reported independently and cannot replace one another.
7. **Review critical documents at most three times.** Use a separately approved sanitized copy and a no-clobber ledger. Round 1 should find all reasonably discoverable material issues together; non-serious findings become non-blocking Open Issues.

## 2. When to use this skill

Use it when:

- a project has fixed roles such as lead, product, development, UI, QA, deployment, and Issue management;
- those roles live in registered Codex tasks;
- the project requires continuous handoff, strict authority boundaries, and traceable acceptance;
- a PRD, Spec, architecture, workflow, implementation plan, acceptance matrix, or production runbook requires independent Hermes review.

Do not use it when:

- the request is a one-off answer or a simple task that needs no durable records;
- the user wants the current task to complete the work directly and there are no fixed roles or cross-task routes;
- a critical-document gate is mandatory, Hermes CLI is unavailable, and the user does not permit an approved alternative process.

## 3. Installation and dependencies

### 3.1 Install the skill

```powershell
git clone https://github.com/Vange-wang/vange-workflow.git "$HOME\.codex\skills\vange-workflow"
```

If the directory already exists, check it for local modifications before updating it. Never overwrite user changes blindly. Reopen the Codex task so Codex can discover the skill.

### 3.2 Required environment

- Codex Desktop or a Codex client with equivalent task-management capabilities;
- PowerShell 7;
- Hermes CLI, or an equivalent reviewer CLI explicitly approved by the user;
- a configured DeepSeek API for the default setup;
- `deepseek-v4-pro` as the recommended model for each default Hermes invocation.

`deepseek-v4-pro` is recommended, not an irreplaceable requirement. An alternative model requires explicit user approval and a recorded capability basis showing that its reasoning and review ability is not materially weaker than the product manager, project lead, and independent QA. The script uses Hermes `--usage-file` evidence to verify the actual runtime model, rejects silent fallback, and compares default-model snapshots before and after the invocation.

A desktop controller must not download or install a reviewer CLI without asking for and receiving user approval. If no CLI can be used, the controller may only request authorization to create a separate independent review task. It must not create that task automatically or replace independent review with author self-review.

```powershell
pwsh -NoLogo -NoProfile -File .\scripts\review_critical_document.ps1 -Mode Preflight
```

Preflight verifies the CLI path, version, configuration, current default-model snapshot, and `--usage-file` support. `default_model_changed` can only be determined by comparing snapshots before and after a real review; preflight never fabricates that result.

### 3.3 Adapter boundary for alternative reviewer CLIs

The packaged `review_critical_document.ps1` is a **Hermes CLI adapter**. It cannot become a generic driver for Cursor, Claude Code, OpenCode, Zcode, or another CLI merely by changing the executable name. A user-approved alternative reviewer requires a separately implemented and validated adapter that preserves the same contract: non-interactive CLI execution, access only to an approved sanitized copy, unchanged source hashes before and after review, verifiable actual model/provider evidence, silent-fallback rejection, one shared append-only `n/3` ledger, no-clobber formal report and metadata, the same report schema, and candidate-only gate states. If any requirement is missing, use the compatibility state `HERMES_REVIEW_BLOCKED`; do not claim equivalent review.

## 4. Project repository structure

The structure follows this precedence: **the Codex project is canonical, and the WorkBuddy project contributes only responsibilities missing from Codex. When they conflict, keep Codex naming, hierarchy, and ownership.** Learn directory responsibilities only. Do not copy sample project files, business names, source code, reports, assets, or device names.

See [project-repository-structure.md](references/project-repository-structure.md) for the complete specification.

### 4.1 Required directories

```text
规划文档/
协同工作文档/
├─ AGENT身份注册信息/
└─ ISSUE/
   ├─ Open_Issue/
   ├─ Close_Issue/
   ├─ Withdrawn_Issue/
   └─ Issue_List/
总负责人文档/
└─ 问题分析与任务预案/
```

These are responsibility areas for a structured multi-role project. They may initially contain no business files, but another role's directory cannot replace their responsibility.

### 4.2 Conditional directories

| Feature | Trigger | Directory created |
| --- | --- | --- |
| `Code` | The project contains code | `Code文档` |
| `Spec` | A formal PRD or Spec begins | `规划文档/Spec文档` |
| `Milestones` | Delivery is divided into stages | `规划文档/里程碑文档` |
| `ProductIteration` | Product behavior is versioned | `规划文档/产品迭代` |
| `TechnicalValidation` | Research, PoC, or feasibility validation exists | `规划文档/技术验证` |
| `UI` | UI, visual, asset, or design acceptance work exists | `UI美术文档` |
| `DomainReferences` | Hardware or specialist reference material exists | `领域参考资料`; an existing `硬件参考` may remain |
| `Hermes` | The first critical-document Hermes review starts | `协同工作文档/Hermes_handoff` |
| `DocumentQA` | A serious document finding enters QA remediation | `协同工作文档/文档QA` |
| `Communication` | Decision-bearing communication must persist | `协同工作文档/交流记录` |
| `Notifications` | Formal notice and alignment evidence is required | `协同工作文档/通知与对齐` |
| `SessionArchive` | Task continuity evidence must be exported | `协同工作文档/会话存档` |
| `DecisionRecords` | A separate checklist or ruling is required | `协同工作文档/清单与裁决` |
| `ReviewReports` | Review evidence needs a dedicated area | `协同工作文档/审查报告` |
| `AcceptanceClarification` | Acceptance has conditions or questions | `协同工作文档/验收与澄清` |
| `CompletionReports` | A stage has formally passed acceptance | `协同工作文档/完成报告` |
| `TechnicalNotes` | A code project needs technical notes | `Code文档/技术笔记` |
| `EnvironmentValidation` | Environment validation is required | `Code文档/环境验证` |
| `SelfTestReports` | Producer self-test reports are required | `Code文档/自测报告` |
| `Scripts` | Project-owned automation exists | `Code文档/scripts` |
| `Tests` | Executable tests exist | `Code文档/tests` |
| `CodeDocs` | Code-local documentation is required | `Code文档/docs` |

`UI美术文档` is not created by default. Codex already uses designated role directories, role anchors, and append-only work records, so do not create generic WorkBuddy/Zcode role-handoff trees. Keep only one `Hermes_handoff` for critical-document review.

### 4.3 Preview and initialize directories

`Plan` shows what would be created without modifying the project:

```powershell
pwsh -NoLogo -NoProfile -File .\scripts\initialize_project_structure.ps1 `
  -Path <project-root> `
  -Mode Plan `
  -Features Code,Spec,Milestones,Hermes
```

After confirming the Feature decisions and directory list, apply the structure:

```powershell
pwsh -NoLogo -NoProfile -File .\scripts\initialize_project_structure.ps1 `
  -Path <project-root> `
  -Mode Apply `
  -Features Code,Spec,Milestones,Hermes
```

`Apply` first checks every target for same-name file conflicts and reparse/junction risks, then creates missing directories only. If creation fails, it attempts to roll back only empty directories created by that invocation. It never moves, renames, or deletes existing project content. A normal repository scan does not authorize automatic creation.

**Capability boundary: the initializer creates directories only. It does not generate PRDs, Specs, task packets, Issues, acceptance reports, code, or any other document content.** Those deliverables are created by their responsible roles only after a user or project trigger formally commissions them.

### 4.4 Audit an existing project

```powershell
pwsh -NoLogo -NoProfile -File .\scripts\project_intake.ps1 `
  -Path <project-root> `
  -Format Json
```

Check:

- `repository_structure.status`;
- `scan.complete` and `scan.diagnostics`;
- `missing_applicable_core`;
- observed `conditional` directory state;
- Git dirty state;
- `AGENTS.md`, canonical-source candidates, the Issue table, and role-registry candidates;
- whether code indicators make `Code文档` applicable.

`CONFORMANT_AT_CORE_LEVEL` proves only that core directories exist. The lead must still verify conditional triggers, ownership, and the unique canonical source before recording `STRUCTURE_GATE_PASSED`.

## 5. Fixed Codex tasks and thread IDs

In this manual, “task,” “thread,” “chat,” and “session” refer to the same kind of Codex collaboration unit. Tool names normally use `thread`.

### 5.1 Register a fixed-role task

A role registration record contains at least:

```text
Project:
Role:
Codex task title:
Task ID:
Host ID (when applicable):
Status: active / archived / superseded
Exclusive write scope:
Forbidden scope:
Role anchor / work-record path:
Upstream input:
Downstream receiving role:
Last validation time:
```

A title or historical memory may help discovery but cannot replace the task ID. Preserve old IDs as archived history; never overwrite the current valid binding.

### 5.2 Find a task

Use `list_threads` to retrieve tasks, then filter the returned data by project name, role, or exact title. The current tool has no `query` parameter:

```text
Operation: list_threads
Input: limit=<reasonable-number>
Output: candidates containing threadId, hostId, title, status, and related fields
Post-processing: filter the returned results by project, role, and exact title; use list_archived_threads separately when historical tasks are needed
```

If no unique candidate exists, return `ROLE_THREAD_UNAVAILABLE` or `REGISTRY_INCOMPLETE`. Never guess an ID.

### 5.3 Validate the binding

Use `read_thread` to inspect recent state:

```text
Operation: read_thread
Input: threadId=<registered-id>, hostId=<registered-host-when-applicable>, turnLimit=<small-recent-window>
Check: title, project, role, current status, latest task, and registration evidence agree
```

Reject archived targets, superseded IDs, project mismatches, role mismatches, and overlapping write scopes. Record `THREAD_BINDING_MISMATCH`, `ROLE_THREAD_UNAVAILABLE`, or `WRITE_SCOPE_CONFLICT` as appropriate.

### 5.4 Send an update to an existing task

Use `send_message_to_thread`:

```text
Operation: send_message_to_thread
Input:
  threadId=<validated-id>
  hostId=<when-applicable>
  prompt=<complete bounded role-task packet>
Default: omit model and thinking so the task keeps its current settings
```

Recommended task packet:

```text
Task ID / execution role / target task ID:
Goal and confirmed upstream conclusions:
Allowed inputs:
Output and exclusive write scope:
Frozen scope / forbidden actions:
Acceptance criteria / required evidence:
Downstream receiving role:
Blocked return: state / exact blocker / minimum unblock input / resume action
Completion return: artifacts / changes / command results / risks / suggested gate
```

Send one bounded role task per message. Do not attach unrelated lead-thread history.

### 5.5 Continue following the same task

- When `wait_threads` exists, use its returned cursor to wait for state changes without redelivering completed output.
- Without `wait_threads`, use `read_thread` for compact snapshots at reasonable progress intervals; do not poll aggressively.
- When a role must add evidence, continue sending requirements to the same `threadId`. Do not create a new task or duplicate implementation.
- A timeout, silence, or one failure does not authorize the lead to take over specialist work.
- Whenever another legal action exists, the lead routes it immediately. When blocked, record the owner, minimum unblock input, and resume trigger.

### 5.6 Update a task ID or rebind a role

Rebind only when the old task is unavailable, explicitly superseded, or the user approved migration:

1. validate the old ID and current status;
2. validate the new task's project, role, title, and write scope;
3. append the new binding in `AGENT身份注册信息` without deleting history;
4. update that role's own anchor and append-only work record;
5. mark the old ID archived or superseded;
6. record unfinished work, blockers, evidence, and one next action;
7. send the continuation packet to the new ID and read it back to confirm the binding.

One role cannot modify another role's registration. Only an authorized project lead or registry administrator may update the central registry.

### 5.7 Create a Codex task

Create a task only when the user explicitly requests it:

1. use `list_projects` to find the target project ID;
2. use `create_thread` with the local project or an isolated worktree;
3. do not override model or reasoning effort unless the user requested it;
4. record the returned `threadId` in the role registry;
5. validate the binding with `read_thread`;
6. show the new task entry to the user.

`fork_thread`, `handoff_thread`, rename, pin, archive, and unarchive operations also require an explicit user request. Creating a subagent is a separate authorization and cannot be inferred from words such as “roles,” “parallel,” or “lead.”

## 6. Standard execution loop

1. Restate the goal and non-goals in one sentence.
2. Read the nearest `AGENTS.md` and only the canonical sources needed for the current gate.
3. Confirm the role, authority, dirty state, acceptance criteria, blockers, and unique next action.
4. Validate the role task ID.
5. Send the minimum packet to the single responsible role.
6. Continue following the original task.
7. Inspect returned artifacts and evidence without recreating the role's work.
8. Return defects to the original owner.
9. Run targeted checks and affected regression checks.
10. After a pass, route to the downstream role, independent reviewer, Issue manager, or user acceptance.
11. Keep `WORKFLOW_ACTIVE` until every gate passes.

Parallel work is allowed only when write scopes are disjoint and no unresolved dependency exists.

## 7. Critical documents: Hermes and Document QA

This branch applies to PRDs, Specs, architectures, frameworks, workflows/processes, implementation plans, acceptance matrices, production/security/deployment runbooks, and other multi-role canonical sources.

### 7.1 Before review

1. The author completes a coherent draft after sufficient reasoning.
2. Freeze the canonical source and record its SHA-256, bytes, lines, stable task ID, and frozen Scope ID.
3. Create `Hermes_handoff`.
4. A separate owner produces a sanitized copy and records its approver or approval ID. The script does not sanitize, and the canonical source must never be passed as the review copy.
5. Run preflight. The script derives one append-only JSONL ledger in `Hermes_handoff` from the task ID, canonical path, and Scope ID.
6. Document QA may be validated in advance, but a missing registration does not block round 1. A valid QA owner becomes mandatory only when serious findings require remediation.

The same task + canonical source + frozen scope permits at most three real invocations. A `review_started` event consumes a round. Invocation failure, retry, revision, report rename, or model change never refunds it.

### 7.2 Run round 1

```powershell
pwsh -NoLogo -NoProfile -File .\scripts\review_critical_document.ps1 `
  -Mode Review `
  -Source <absolute-canonical-document-path> `
  -ReviewCopy <absolute-approved-sanitized-copy-path> `
  -HandoffDirectory <absolute-Hermes_handoff-path> `
  -Report <absolute-new-round-1-report-path> `
  -TaskId <stable-task-id> `
  -ScopeId <stable-frozen-scope-id> `
  -SanitizationApprovedBy <approver-or-approval-id> `
  -Round 1 `
  -ReviewModel deepseek-v4-pro `
  -ReviewTimeoutSeconds 600
```

Round 1 must report all reasonably discoverable material issues together.

`SERIOUS` means a material impact on correctness, approved scope, feasibility, security/privacy, irreversible decisions, failure handling, acceptance/testability, or downstream execution.

`NON_SERIOUS` means wording, style, optional enhancement, or local clarity. Record it as a non-blocking Open Issue; it does not trigger repeated document revision.

The script strictly parses the machine header, finding counts, and required sections and verifies the actual model through `--usage-file`. A call times out after 600 seconds by default and may be explicitly configured from 30 to 3600 seconds; timeout still consumes the round. If the model returns content with an invalid schema, raw stdout is saved only as a same-name `.rejected.md` diagnostic artifact and is never promoted to the formal report. A successful run emits `HERMES_INVOCATION_PASS`, then `HERMES_REPORT_VALIDATED`, followed by one state:

- `QA_DOCUMENT_REWORK`: serious findings remain and another round is available;
- `DOCUMENT_REVIEW_LIMIT_REACHED`: serious findings remain after round 3;
- `DOCUMENT_GATE_CANDIDATE`: the automated report meets candidate conditions, but external gates remain.

### 7.3 Document QA remediation

- Send the complete `SERIOUS` batch to the registered Document QA task in one packet.
- QA edits only the named canonical source and its remediation ledger.
- QA cannot approve its own revision.
- The project lead cannot edit the document on QA's behalf.
- QA returns the new SHA, exact diff, per-Finding disposition, and verification evidence.

### 7.4 Rounds 2–3

Verify serious fixes and affected regressions only; do not reopen aesthetic whole-document polishing:

```powershell
pwsh -NoLogo -NoProfile -File .\scripts\review_critical_document.ps1 `
  -Mode Review `
  -Source <absolute-current-canonical-document-path> `
  -ReviewCopy <absolute-new-approved-sanitized-copy-path> `
  -HandoffDirectory <same-absolute-Hermes_handoff-path> `
  -Report <absolute-new-round-2-report-path> `
  -TaskId <same-stable-task-id> `
  -ScopeId <same-stable-frozen-scope-id> `
  -SanitizationApprovedBy <approver-or-approval-id> `
  -Round 2 `
  -ReviewModel deepseek-v4-pro `
  -ReviewTimeoutSeconds 600
```

A newly reported serious issue must be proven to have been introduced by the revision or not reasonably discoverable in round 1. Editing files, renaming reports, changing tasks, retrying, or producing a new SHA does not reset the round count.

If serious findings remain after round 3, set `DOCUMENT_REVIEW_LIMIT_REACHED` and request a user decision. Never start round 4 automatically.

After `DOCUMENT_GATE_CANDIDATE`, the lead must still verify the actual model, final hash, report/metadata/ledger, unrelated diff, non-serious Issue ownership, and—only when QA remediation occurred—the QA ledger. Set `DOCUMENT_GATE_PASSED` only after all applicable evidence passes, then enter `USER_CONFIRMATION_PENDING`. Do not start downstream implementation before user confirmation.

## 8. Issues, blockers, and rework

- Ordinary defect: `REWORK_REQUIRED`; return it to the artifact owner.
- Credential, platform, or external-authority blocker: `EXTERNAL_BLOCKED`.
- Failed upstream gate: `UPSTREAM_GATE_BLOCKED`.
- Unavailable task: `ROLE_THREAD_UNAVAILABLE`.
- Out-of-role assignment: `ROLE_BOUNDARY_BLOCKED`; perform no mutation.
- Unavailable Hermes review: `HERMES_REVIEW_BLOCKED`; do not substitute a weak model or expose restricted data.
- Session continuation required: `SESSION_RELAY_REQUIRED`.

A blocker record must name the exact blocker, owner, safe checks attempted, minimum unblock input, resume trigger, and unique next action. A blocker is non-terminal. It does not authorize scope expansion and does not mean the project is complete.

## 9. Acceptance and completion

Before `WORKFLOW_COMPLETE`, verify that:

- the current canonical source and every required deliverable exist;
- each deliverable has verification evidence from its responsible role;
- independent review passed;
- the critical-document gate passed;
- blocking Open Issues are closed;
- local, integration, production, and human acceptance passed separately;
- user/Boss gates passed;
- continuity records contain no unfinished gate;
- every residual risk is explicitly non-blocking and has an owner.

The only exception that permits stopping is an explicit user instruction to pause, stop, or cancel. Record `USER_PAUSED` and the user's exact instruction. Context compaction, closing a client, or task migration is not stop authorization.

## 10. Durable record templates

[contracts.md](references/contracts.md) provides templates for:

- Workflow ledger;
- Decision record;
- Role task packet;
- Critical-document record;
- Blocker/relay record;
- Acceptance record.

Create a durable record only when the project needs persistent evidence. Do not create documents merely to repeat chat content.

## 11. Validate the skill

```powershell
$env:PYTHONUTF8 = '1'
python "$HOME\.codex\skills\.system\skill-creator\scripts\quick_validate.py" .

pwsh -NoLogo -NoProfile -File .\tests\validate_lean_skill.ps1 -Path .
pwsh -NoLogo -NoProfile -File .\tests\run_scenarios.ps1 -Path .
pwsh -NoLogo -NoProfile -File .\tests\test_project_tools.ps1 -Path .
pwsh -NoLogo -NoProfile -File .\tests\test_review_critical_document.ps1 -Path .

# Calls the real review API and sends only generated, non-sensitive test text
pwsh -NoLogo -NoProfile -File .\tests\run_real_hermes_smoke.ps1 -Path .
```

The smoke test does not read a real project document and does not consume a real project's review ledger. If a Codex/desktop sandbox blocks local child processes required by Hermes, such as the Git Bash file reader, the controller must request user approval for local execution before rerunning the same smoke or formal review command. It must not silently weaken the security boundary or launch parallel model calls.

Also run:

- PowerShell parser checks;
- `Plan`/`Apply`, idempotency, same-name-file blocking, and scanner code-detection tests for project structure tooling;
- Hermes Preflight;
- mock-Hermes path-collision, actual-model, report-schema, round-ledger, and no-clobber tests;
- at least one real Hermes integration review with non-sensitive input before release;
- Gitleaks or GitHub Secret Scanning;
- Git dirty-state, commit-SHA, and remote-`main`-SHA comparison.

Keyword or structural validation proves only that a rule exists. Behavioral tests prove the behavior of covered scenarios. Even when every package test passes, they do not prove that a project using this skill has completed its own acceptance.

## 12. Publish an update

Before release:

1. treat the currently installed skill as the canonical source;
2. synchronize files individually into the release repository;
3. keep README, LICENSE, and `.gitignore` as release packaging only;
4. compare the skill file list and raw object hashes;
5. run all validation;
6. scan for secrets;
7. inspect the exact diff;
8. commit and push normally; never force-push;
9. compare local and remote SHAs;
10. confirm file identity again from raw remote Git objects.

## 13. Security boundaries

- Never put API keys, tokens, cookies, private keys, or unsanitized documents in the repository, reports, logs, screenshots, or chat.
- Hermes reviews only a sanitized copy produced and explicitly approved by a separate owner. The script never sanitizes automatically and never treats the canonical source as a safe copy.
- Continuous follow-up does not expand deployment, payment, publishing, credential, privacy, or security authority.
- A directory template does not authorize moving existing project content.
- A missing role does not authorize the project lead to substitute for it.
- A local test, HTTP 200, successful build, or Git push is not production or user acceptance.

## License

[MIT License](LICENSE)
