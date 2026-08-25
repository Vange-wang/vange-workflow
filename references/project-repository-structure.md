# Project Repository Structure

Load when initializing, onboarding, auditing, or intentionally reorganizing a project repository. The merged map below is canonical: the Codex structure is primary, and WorkBuddy adds only non-conflicting responsibilities absent from Codex. Future unmapped conflicts keep the Codex naming, placement, and ownership model.

Learn directory roles only. Do not copy sample project files, filenames, source, reports, assets, logs, credentials, business/device names, or tool-specific role folders.

## Creation modes

- **Audit mode:** run `scripts/project_intake.ps1`; report evidence and gaps only. Do not create, rename, move, or delete.
- **Initialization/structure-setup mode:** only when that mutation is explicitly in scope, run `scripts/initialize_project_structure.ps1` first with `-Mode Plan`, confirm the selected feature triggers, then use `-Mode Apply`. Apply is idempotent and only creates missing directories.
- Required responsibility roots may initially be empty. Conditional branches are generated only when their named trigger becomes true; do not pre-create speculative empty folders.
- An established equivalent may remain only when its owner, canonical source, write scope, and mapping to this structure are recorded without overlap.

## Canonical map

```text
<project-root>/
|-- 规划文档/                                  [Codex required]
|   |-- Spec文档/                             [Codex conditional: formal PRD/Spec]
|   |-- 里程碑文档/                           [Codex conditional: staged delivery]
|   |-- 产品迭代/                             [Codex conditional: version iteration]
|   `-- 技术验证/                             [Codex conditional: research/PoC]
|-- 协同工作文档/                              [Codex required]
|   |-- AGENT身份注册信息/                    [Codex required: bindings/work records]
|   |-- ISSUE/                                [Codex required]
|   |   |-- Open_Issue/
|   |   |-- Close_Issue/
|   |   |-- Withdrawn_Issue/
|   |   `-- Issue_List/
|   |-- 交流记录/                             [Codex conditional: durable communication]
|   |-- 文档QA/                               [Codex conditional: QA remediation]
|   |-- Hermes_handoff/                       [conditional: first Hermes review]
|   |-- 通知与对齐/                           [WorkBuddy supplement: formal notice]
|   |-- 会话存档/                             [WorkBuddy supplement: exported continuity]
|   |-- 清单与裁决/                           [WorkBuddy supplement: formal decision list]
|   |-- 审查报告/                             [WorkBuddy supplement: separate review evidence]
|   |-- 验收与澄清/                           [WorkBuddy supplement: acceptance clarification]
|   `-- 完成报告/                             [WorkBuddy supplement: accepted-stage summary]
|-- 总负责人文档/                              [Codex required]
|   `-- 问题分析与任务预案/                   [Codex required]
|-- Code文档/                                  [Codex conditional: project contains code]
|   |-- <application, firmware, service, API, bridge, data, public assets, platform config>/
|   |-- 技术笔记/                             [WorkBuddy supplement: needed]
|   |-- 环境验证/                             [WorkBuddy supplement: needed]
|   |-- 自测报告/                             [WorkBuddy supplement: needed]
|   |-- scripts/                              [conditional: automation]
|   |-- tests/                                [conditional: executable verification]
|   `-- docs/                                 [conditional: code-local documentation]
|-- UI美术文档/                                [Codex conditional: UI/visual/design work]
`-- 领域参考资料/                              [WorkBuddy supplement: hardware/domain references]
```

Do not create generic per-role handoff directories. Codex task orders and continuity stay in its registered-role anchors and append-only work records; WorkBuddy sample directories such as `zcode_tasks`, `zcode_handoff`, and `WB_handoff` are deliberately excluded. Only `Hermes_handoff` is added for sanitized Hermes review packets and review continuity. Existing `硬件参考` is accepted as the domain-specific equivalent of `领域参考资料`.

`Code文档` follows the actual stack. Do not copy sample routes or force web conventions onto firmware, services, automation, research, or non-code projects. Tool state, caches, dependencies, generated output, models, logs, and temporary sync directories are never template branches.

## Feature trigger registry

Before `-Mode Apply`, record `selected_features`, trigger evidence, owner, and timestamp in the authorized lead task plan or workflow ledger. Use these deterministic triggers:

| Feature | Trigger |
| --- | --- |
| `Code` | A code manifest, recognized source extension, or approved implementation scope exists. |
| `Spec` | A formal PRD or Spec is commissioned. |
| `Milestones` | Delivery has named stages or stage acceptance. |
| `ProductIteration` | Product behavior is managed across versions. |
| `TechnicalValidation` | Research, PoC, feasibility, or technical preflight is required. |
| `UI` | UI, visual, asset, or design acceptance work is in scope. |
| `DomainReferences` | Hardware or specialist reference material is governed by the project. |
| `Hermes` | The first critical-document Hermes review starts. |
| `DocumentQA` | A serious document finding enters QA remediation. |
| `Communication` | A decision-bearing exchange must persist outside chat. |
| `Notifications` | Formal notice/alignment evidence is required. |
| `SessionArchive` | A task/session export is required for continuity. |
| `DecisionRecords` | A separate checklist or formal ruling is required. |
| `ReviewReports` | Review evidence needs a dedicated area beyond `文档QA` or `Hermes_handoff`. |
| `AcceptanceClarification` | Acceptance has questions, conditions, or residual-risk clarification. |
| `CompletionReports` | A stage has passed its applicable acceptance gates. |
| `TechnicalNotes` | Code-local technical notes are required. |
| `EnvironmentValidation` | Environment setup or compatibility needs evidence. |
| `SelfTestReports` | Producer self-test evidence is required. |
| `Scripts` | Project-owned automation scripts exist. |
| `Tests` | Executable project verification exists. |
| `CodeDocs` | Documentation is owned with the code rather than project planning. |

`project_intake.ps1` recognizes source extensions `.c`, `.cc`, `.cpp`, `.cs`, `.go`, `.h`, `.hpp`, `.ino`, `.java`, `.js`, `.jsx`, `.kt`, `.py`, `.rs`, `.swift`, `.ts`, and `.tsx`, plus common manifests. The selected-feature record remains the authority for conditions the scanner cannot infer.

## Observable conformance

`STRUCTURE_GATE_PASSED` requires all of the following:

1. `规划文档`, `协同工作文档/AGENT身份注册信息`, the four `ISSUE` state/list directories, and `总负责人文档/问题分析与任务预案` exist.
2. `Code文档` exists when code indicators exist; each other conditional branch exists only when its trigger is recorded as applicable.
3. No generic role-handoff tree duplicates Codex role anchors/work records; Hermes uses only `Hermes_handoff`.
4. Each accepted equivalent is mapped in the authorized lead task plan or workflow ledger with one owner, canonical source, exact write scope, and no competing mutable source.
5. `project_intake.ps1 -Path <project-root> -Format Json` reports `CONFORMANT_AT_CORE_LEVEL`; the lead verifies the selected-feature record and records the structure verdict. That scanner state covers applicable core-path existence, code applicability, and observed optional aliases only. It does not verify semantic ownership, trigger truth, mutation authority, or final acceptance.

Code, UI, QA, review, deployment, and domain-reference branches retain separate owners and gates. The project lead governs structure and routing but does not write specialist deliverables.
