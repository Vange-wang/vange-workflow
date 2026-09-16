# Quick Start

This guide is a short orientation, not a promise of a complete multi-role run in 5–10 minutes. The local checks below are executable; the role walkthrough is **conceptual and has not been run as a real Codex collaboration**.

中文读者：本页包含可执行的只读入门检查和明确标注的概念协作示例；完整规则见[中文手册](../README.cn.md)。安装不会自动创建角色、补齐客户端工具或完成验收。

## 1. Check prerequisites and fit

- Git and PowerShell 7 for the installation and local commands below.
- Codex Desktop or a Codex client exposing the required task-management capabilities. Not every client provides them; installing a skill does not add missing tools.
- For actual critical-document review, the default setup requires Hermes CLI, a configured DeepSeek API, and the recommended `deepseek-v4-pro` model. Installing a reviewer CLI requires explicit approval. An alternative reviewer/model follows the [existing approval and adapter rules](../README.md#32-required-environment).

The structure preview, scanner, and structural validator below do not call Hermes or require an API key. They also do not prove that real review is configured.

Use the skill when a project has registered specialist roles, persistent handoffs, and traceable acceptance requirements. For a one-off answer or a simple task handled directly in one task, use the ordinary task workflow instead.

## 2. Install or inspect the installation

The conventional installation directory is `$HOME\.codex\skills\vange-workflow`. If you use a custom skill location, follow your client's configuration and adjust the path consistently. These are PowerShell examples; verified macOS/Linux support is not claimed.

Run this only for a new installation. The guard stops if the target already exists:

```powershell
$skillRoot = Join-Path $HOME '.codex\skills\vange-workflow'
if (Test-Path -LiteralPath $skillRoot) {
    throw 'An installation already exists. Inspect its local changes before updating.'
}
git clone https://github.com/Vange-wang/vange-workflow.git $skillRoot
if ($LASTEXITCODE -ne 0) { throw 'Clone failed; stop and inspect the error.' }
Set-Location -LiteralPath $skillRoot
```

For an existing Git installation, inspect it first with `git -C "$HOME\.codex\skills\vange-workflow" status --short`. Do not overwrite local changes or assume the public repository and installed runtime are identical. This guide does not automatically update an installation.

Reopen the Codex task. Use the client's available-skill list to confirm that `vange-workflow` is discoverable. If that list is not exposed, ask the task to identify the skill's resolved `SKILL.md` location and summarize its boundaries without creating tasks or editing files. A response based only on the project name is not proof of discovery. If the skill is missing, inspect the installation path and client skill support before proceeding; a local validator pass does not prove client discovery.

## 3. Run local, read-only checks

Run from the skill root. Choose an **existing disposable test directory** you are authorized to inspect; use synthetic content and replace the example path below. Do not point the scanner at unrelated private projects.

```powershell
$skillRoot = Join-Path $HOME '.codex\skills\vange-workflow'
Set-Location -LiteralPath $skillRoot
$testProject = 'C:\path\to\your\existing-test-project'
if (-not (Test-Path -LiteralPath $testProject -PathType Container)) {
    throw 'Replace $testProject with an existing test directory.'
}

pwsh -NoLogo -NoProfile -File .\scripts\initialize_project_structure.ps1 `
    -Path $testProject -Mode Plan -Format Json
if ($LASTEXITCODE -ne 0) { throw 'Structure preview failed.' }

pwsh -NoLogo -NoProfile -File .\scripts\project_intake.ps1 `
    -Path $testProject -Format Json
if ($LASTEXITCODE -ne 0) { throw 'Project scan failed.' }

pwsh -NoLogo -NoProfile -File .\tests\validate_lean_skill.ps1 -Path .
if ($LASTEXITCODE -ne 0) { throw 'Structural skill validation failed.' }
```

Expected result categories, not a captured success transcript:

- `Plan`: proposed directory entries and whether they can be applied. No project directories are created. Conditional features require a separate decision; this command selects none.
- Intake: `scan.complete`, diagnostics, and observed structure. An empty test directory can legitimately report `STRUCTURE_REVIEW_REQUIRED`. Incomplete scans need investigation. Even `CONFORMANT_AT_CORE_LEVEL` does not establish ownership or final acceptance.
- Validator: a failure count and, on success, `LEAN_SKILL_VALIDATION_PASS`. This checks packaged rules and structure, not a real multi-role workflow or Hermes integration.

Do not switch to `Apply` just to remove a warning. Directory initialization is a separately authorized action; see the [structure manual](../README.md#4-project-repository-structure).

## 4. Conceptual walkthrough: lead, developer, QA

**Synthetic example only.** Suppose a user has approved a small change to a demo text file so it contains exactly `Hello, Ada.`. There is no production deployment in this example. The three role tasks already exist, the project registry and role record locations are authorized, and cross-task collaboration has been explicitly authorized. This guide creates none of them.

### Register and validate the existing roles

Use the [role registration fields](../README.md#51-register-a-fixed-role-task) and [routing contract](../references/thread-routing.md). An authorized registry owner records the project, role, actual task ID, title, host if applicable, active status, exclusive write scope, forbidden scope, role anchor/work record, upstream input, downstream receiver, and last validation time. Each role maintains its own authorized records; do not modify another role's binding implicitly.

The following placeholders are not usable task IDs:

| Role | ID placeholder | Example exclusive output | Forbidden scope |
| --- | --- | --- | --- |
| Project lead | `<validated-lead-task-id>` | Authorized lead ledger under `总负责人文档/` | Developer output, QA verdict |
| Developer | `<validated-developer-task-id>` | `Code文档/demo.txt` and its own designated work record | QA report, role bindings |
| QA | `<validated-qa-task-id>` | `协同工作文档/审查报告/demo-qa.md` and its own designated work record | Developer file, another role's binding |

Record concrete, non-overlapping scopes before dispatch. Validate real IDs and current role state through the client's task tools when available. Never send a placeholder ID or invent an API. Missing or mismatched bindings require resolution, not automatic task creation or lead takeover.

### Follow the handoffs

1. **Lead → Developer:** send a bounded task packet to the validated, registered developer. Include the approved goal, exact file, permitted input, exclusive write scope, unchanged files, acceptance criterion, and required evidence. For this example, the criterion is exact text `Hello, Ada.` in `Code文档/demo.txt`; no unrelated file changes are permitted.
2. **Developer → Lead:** return the artifact path, precise diff or commit, actual self-check command/result, and any blocker. A useful self-check reads the file and compares its text against the agreed value. Do not report a check that was only planned.
3. **Lead → QA:** inspect scope and evidence, then route the same identified artifact/version and acceptance criterion to the registered QA task. Do not rewrite the file or author QA's verdict.
4. **QA → Lead:** independently check the text and change scope, then return a pass or findings with attributable evidence in its own report. QA does not silently fix the developer's file. Defects return to the developer and are rechecked against the revised artifact.
5. **Lead → Acceptance:** aggregate the producer and independent evidence, check every applicable gate, and seek user acceptance. Record pending gates as pending. A QA pass alone is not `WORKFLOW_COMPLETE`; closure follows the [existing acceptance rules](../README.md#9-acceptance-and-completion).

Actual client tool usage is documented in [registration and routing](../README.md#5-fixed-codex-tasks-and-thread-ids). This walkthrough is not an automated integration test and contains no pre-populated pass result.

### If a critical-document gate applies

This small example does not commission a PRD or other new critical source. If the real project requires one, follow the [critical-document branch](../README.md#7-critical-documents-hermes-and-document-qa) **before dependent implementation**: freeze scope, use a separately approved sanitized copy, perform the bounded Hermes review, send serious findings to registered Document QA if necessary, and obtain the formal gate and user confirmation. The ordinary QA role above is not automatically a registered Document QA owner.

At most three started review invocations are allowed per frozen scope; an automated candidate is not formal approval or final acceptance. This guide neither triggers that branch nor waives it.

## 5. What this guide does not do

- Create or migrate role tasks, run subagents, or grant cross-task permissions.
- Initialize project directories with `Apply`, generate project documents, or change runtime rules.
- Install/configure a reviewer CLI, contact a real review API, or approve a sanitized copy.
- Deploy, publish, prove cross-platform support, or declare a project complete.

For full rules, return to the [English manual](../README.md) or [中文手册](../README.cn.md).
