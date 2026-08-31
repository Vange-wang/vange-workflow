# Vange Workflow

[English](README.md) | **简体中文**

Vange Workflow 是面向 Codex＋Hermes CLI 的固定角色项目协作 Skill。它解决的不是“让一个 Agent 包办全部工作”，而是让项目总负责人持续路由、跟进、检查证据和控制门禁，由已登记的专业角色分别完成自己的产物，直到全部适用验收通过或用户明确暂停、停止、取消。

本仓库以当前安装版 `vange-workflow` 为唯一规范源。运行时规则见 [SKILL.md](SKILL.md)；本 README 是完整安装与操作手册，不会在 Skill 每次调用时全部载入。

## 1. 核心原则

1. **充分思考后再行动。** 就绪程度是定性判断，不用百分比、时长或清单数量代替。先明确目标、非目标、依赖、失败路径、权限、回滚和验收，再执行。
2. **总负责人不代做。** 总负责人负责路由、持续跟进、证据检查、状态、门禁和收口，不编写专业角色产物、不替慢角色修复、不自审自批。
3. **一个可变产物只有一个责任角色。** 不允许两个任务同时修改同一文件或同一规范源。
4. **只使用已登记任务。** 跨任务协作必须使用现有、有效、已登记的 Codex 任务 ID。创建新任务、fork、subagent 或后台 Agent 必须获得用户明确授权。
5. **未验收不停止。** 计划完成、本地测试通过、单个角色返回、等待超时、遇到阻塞或条件通过都不是项目完成。
6. **证据分层。** 本地、集成、生产、独立审核和用户/Boss 验收分别报告，不能相互替代。
7. **关键文档最多审查三轮。** 使用独立获批的脱敏副本和不可覆盖 ledger；第一轮尽可能一次发现全部重要问题，非严重问题转为非阻塞 Open Issue。

## 2. 适用场景

适合：

- 一个项目由总负责人、产品、开发、UI、QA、部署、Issue 管理等固定角色协作；
- 角色分别存在于已登记的 Codex 任务中；
- 项目要求持续接续、严格权限边界和可追溯验收；
- PRD、Spec、架构、流程、实施计划、验收矩阵或生产手册需要 Hermes 独立审查。

不适合：

- 一次性问答或无需持久记录的简单任务；
- 用户希望当前任务直接完成、且不存在固定角色和跨任务路由；
- 未安装 Hermes CLI、但任务又强制要求关键文档门禁且用户不允许替代流程。

## 3. 安装与依赖

### 3.1 安装 Skill

```powershell
git clone https://github.com/Vange-wang/vange-workflow.git "$HOME\.codex\skills\vange-workflow"
```

若目录已经存在，先确认它是否有本地修改；不要直接覆盖用户改动。重新打开 Codex 任务后，Codex 会发现该 Skill。

### 3.2 必需环境

- Codex Desktop 或提供同等任务管理能力的 Codex 客户端；
- PowerShell 7；
- Hermes CLI，或用户明确批准的同等 CLI 审核端；
- 默认方案需配置 DeepSeek API；
- 默认推荐 Hermes 单次调用使用 `deepseek-v4-pro`。

`deepseek-v4-pro` 是推荐方案，不是不可替换的唯一模型。替代模型必须获得用户明确批准，并记录能力依据，证明其推理与审查能力不会明显弱于产品经理、总负责人和独立 QA。脚本通过 Hermes `--usage-file` 核对实际运行模型，拒绝静默 fallback，并比较调用前后的默认模型快照。

桌面端主控不得自行下载或安装审核端 CLI；必须先询问并获得用户批准。如果确实无法使用 CLI，只能请求用户授权在主控端创建独立复核任务；不得自动创建，也不得由原作者自审代替。

```powershell
pwsh -NoLogo -NoProfile -File .\scripts\review_critical_document.ps1 -Mode Preflight
```

预检确认：CLI 路径、版本、配置、当前默认模型快照及 `--usage-file` 支持。`default_model_changed` 只能在真实审查前后比较后得出，预检不会伪造该结论。

### 3.3 替代审核 CLI 的适配边界

仓库内 `review_critical_document.ps1` 是 **Hermes CLI 适配器**，不能通过改可执行文件名直接当成 Cursor、Claude Code、OpenCode、Zcode 等其他 CLI 的通用驱动。使用用户批准的替代审核端时，必须先实现并验证独立适配器，而且仍要满足同一契约：非交互 CLI 调用、仅接收获批脱敏副本、调用前后源文件哈希不变、实际 model/provider 可核验、静默 fallback 被拒绝、共享 append-only `n/3` ledger、正式报告与 metadata 不覆盖、相同报告 schema 和候选门禁状态。缺少任一项就设置 `HERMES_REVIEW_BLOCKED`（兼容状态名），不得宣称等效审核。

## 4. 项目仓库结构

结构来源遵循：**Codex 项目为主模板，WorkBuddy 项目只补充 Codex 没有的职责。发生冲突时采用 Codex 命名、层级和所有权。**这里只学习文件夹职责，不复制任何样本项目文件、业务名称、源码、报告、素材或设备名称。

完整规范见 [project-repository-structure.md](references/project-repository-structure.md)。

### 4.1 初始化必建目录

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

这些是结构化多角色项目的责任区域。目录可以暂时没有业务文件，但不能用其他角色的目录替代其责任。

### 4.2 按条件生成

| Feature | 触发条件 | 生成目录 |
| --- | --- | --- |
| `Code` | 项目包含代码 | `Code文档` |
| `Spec` | 开始正式 PRD/Spec | `规划文档/Spec文档` |
| `Milestones` | 项目按阶段交付 | `规划文档/里程碑文档` |
| `ProductIteration` | 存在产品版本迭代 | `规划文档/产品迭代` |
| `TechnicalValidation` | 存在预研、PoC、可行性验证 | `规划文档/技术验证` |
| `UI` | 存在 UI、视觉、素材或设计验收 | `UI美术文档` |
| `DomainReferences` | 存在硬件或专业领域参考 | `领域参考资料`；已有 `硬件参考` 可保留 |
| `Hermes` | 首次启动关键文档 Hermes 审查 | `协同工作文档/Hermes_handoff` |
| `DocumentQA` | 关键文档出现严重问题并进入 QA 修订 | `协同工作文档/文档QA` |
| `Communication` | 关键交流需要持久化 | `协同工作文档/交流记录` |
| `Notifications` | 需要正式通知与对齐证据 | `协同工作文档/通知与对齐` |
| `SessionArchive` | 需要导出任务连续性证据 | `协同工作文档/会话存档` |
| `DecisionRecords` | 需要独立清单或裁决记录 | `协同工作文档/清单与裁决` |
| `ReviewReports` | 需要独立审查报告区域 | `协同工作文档/审查报告` |
| `AcceptanceClarification` | 验收存在澄清或条件 | `协同工作文档/验收与澄清` |
| `CompletionReports` | 阶段已经正式验收 | `协同工作文档/完成报告` |
| `TechnicalNotes` | 代码项目需要技术笔记 | `Code文档/技术笔记` |
| `EnvironmentValidation` | 需要环境验证 | `Code文档/环境验证` |
| `SelfTestReports` | 需要自测报告 | `Code文档/自测报告` |
| `Scripts` | 存在自动化脚本 | `Code文档/scripts` |
| `Tests` | 存在可执行测试 | `Code文档/tests` |
| `CodeDocs` | 需要代码内部文档 | `Code文档/docs` |

`UI美术文档` 不默认创建。Codex 已使用钦定角色目录、角色锚点和追加式工作记录，所以不建立 WorkBuddy/Zcode 等通用角色交接树；只为关键文档审查保留一个 `Hermes_handoff`。

### 4.3 预览目录初始化

`Plan` 只显示将创建什么，不修改项目：

```powershell
pwsh -NoLogo -NoProfile -File .\scripts\initialize_project_structure.ps1 `
  -Path <project-root> `
  -Mode Plan `
  -Features Code,Spec,Milestones,Hermes
```

确认 Feature 判断和目录清单后，执行创建：

```powershell
pwsh -NoLogo -NoProfile -File .\scripts\initialize_project_structure.ps1 `
  -Path <project-root> `
  -Mode Apply `
  -Features Code,Spec,Milestones,Hermes
```

`Apply` 先检查全部目标是否存在同名文件或 reparse/junction 风险，再只创建缺失目录；失败时尽可能回滚本次新建的空目录。它不移动、不改名、不删除已有项目内容。普通仓库扫描不构成自动创建授权。

**能力边界：初始化器只生成目录，不会自动生成 PRD、Spec、任务单、Issue、验收报告、代码或其他文档正文。**这些内容仍由对应责任角色在用户或项目正式触发后创建。

### 4.4 审计现有项目

```powershell
pwsh -NoLogo -NoProfile -File .\scripts\project_intake.ps1 `
  -Path <project-root> `
  -Format Json
```

重点检查：

- `repository_structure.status`；
- `scan.complete` 和 `scan.diagnostics`；
- `missing_applicable_core`；
- `conditional` 的实际存在状态；
- Git dirty state；
- `AGENTS.md`、规范源、Issue 总表和角色注册候选；
- 当前项目是否有代码，从而要求 `Code文档`。

`CONFORMANT_AT_CORE_LEVEL` 只证明核心目录齐全。总负责人还要核对条件触发、所有权和唯一规范源，才能记录 `STRUCTURE_GATE_PASSED`。

## 5. Codex 固定任务与线程 ID

Codex UI 中的“任务、线程、聊天、会话”在这里指同一类协作单元。工具名称通常使用 `thread`。

### 5.1 注册一条固定角色任务

角色注册记录至少包含：

```text
项目：
角色：
Codex 任务标题：
任务 ID：
Host ID（如适用）：
状态：active / archived / superseded
唯一写入范围：
禁止范围：
角色锚点/工作记录路径：
上游输入：
下游接收角色：
最后验证时间：
```

任务标题和历史记忆只能帮助搜索，不能替代任务 ID。旧 ID 保留为归档记录，不能覆盖当前有效绑定。

### 5.2 查找任务

让 Codex 使用 `list_threads` 取得任务列表，再在返回结果中按项目名、角色名或精确标题筛选。当前工具没有 `query` 参数：

```text
操作：list_threads
输入：limit=<合理数量>
输出：threadId、hostId、title、status 等候选
后处理：在返回结果中按项目、角色、精确标题筛选；需要历史任务时另用 list_archived_threads
```

如果找不到唯一候选，返回 `ROLE_THREAD_UNAVAILABLE` 或 `REGISTRY_INCOMPLETE`，不得猜 ID。

### 5.3 校验任务绑定

使用 `read_thread` 读取最近状态：

```text
操作：read_thread
输入：threadId=<登记ID>, hostId=<登记Host，如适用>, turnLimit=<少量最近轮次>
检查：标题、项目、角色、当前状态、最近任务和登记信息是否一致
```

拒绝以下目标：已归档、已被新 ID 替代、项目不符、角色不符、写入范围重叠。状态分别记录为 `THREAD_BINDING_MISMATCH`、`ROLE_THREAD_UNAVAILABLE` 或 `WRITE_SCOPE_CONFLICT`。

### 5.4 给现有任务发送更新

使用 `send_message_to_thread`：

```text
操作：send_message_to_thread
输入：
  threadId=<已校验ID>
  hostId=<如适用>
  prompt=<完整且有边界的角色任务包>
默认：不传 model、不传 thinking，保留该任务当前设置
```

推荐任务包：

```text
任务 ID / 执行角色 / 目标任务 ID：
目标与上游已确认结论：
允许读取的输入：
输出与唯一写入范围：
冻结范围 / 禁止事项：
验收标准 / 必须返回的证据：
下游接收角色：
阻塞回报格式：状态 / 阻塞点 / 最小解除输入 / 恢复动作
完成回报格式：产物 / 修改 / 命令结果 / 风险 / 建议门禁
```

每次消息只派发一个有边界的角色任务，不附带无关的总负责人聊天历史。

### 5.5 持续跟进同一任务

- 客户端提供 `wait_threads` 时，使用返回 cursor 等待状态变化，不重复读取已经交付的内容。
- 未提供 `wait_threads` 时，在合理进度间隔后用 `read_thread` 获取紧凑快照，不高频轮询。
- 角色需要补充证据时，继续使用同一 `threadId` 发送补充要求，不另开任务、不重复实现。
- 超时、沉默或一次失败不授权总负责人接管专业工作。
- 只要存在下一项合法动作，总负责人立即继续路由；阻塞时记录所有者、最小解除输入和恢复触发条件。

### 5.6 更新任务 ID 或重新绑定

仅在旧任务不可用、被明确替换或用户批准迁移时进行：

1. 验证旧 ID 当前状态；
2. 验证新任务的项目、角色、标题和写入范围；
3. 在 `AGENT身份注册信息` 中追加新绑定，不删除旧历史；
4. 同步该角色自己的锚点和追加式工作记录；
5. 标记旧 ID 为 archived/superseded；
6. 记录未完成工作、阻塞、证据和唯一下一动作；
7. 用新 ID 发送接续包并再次读取确认。

一个角色不能修改另一个角色的注册绑定。中央登记表只能由获授权的总负责人或登记管理员更新。

### 5.7 创建新 Codex 任务

只有用户明确要求创建时才能执行：

1. 使用 `list_projects` 找到目标项目 ID；
2. 使用 `create_thread`，选择本地项目或隔离 worktree；
3. 未经用户指定，不覆盖模型和推理等级；
4. 获得返回的 `threadId` 后写入注册记录；
5. 再用 `read_thread` 验证绑定；
6. 向用户展示新任务入口。

`fork_thread`、`handoff_thread`、重命名、置顶、归档和取消归档同样需要用户明确请求。创建 subagent 是另一项独立授权，不能由“分工”“并行”“负责人”等字样推定。

## 6. 标准执行循环

1. 用一句话复述目标和非目标；
2. 读取最近的 `AGENTS.md` 和当前门禁所需规范源；
3. 确认角色、权限、dirty state、验收标准、阻塞和唯一下一动作；
4. 校验角色任务 ID；
5. 向唯一责任角色派发最小任务包；
6. 持续跟进原任务；
7. 检查角色返回的产物和证据，但不重做其工作；
8. 缺陷退回原责任角色；
9. 运行目标检查和受影响回归；
10. 通过后交给下游、独立审核、Issue 管理或用户验收；
11. 全部门禁通过前保持 `WORKFLOW_ACTIVE`。

只有写入范围完全分离且不存在未满足依赖时才允许并行。

## 7. 关键文档：Hermes＋Document QA

适用于 PRD、Spec、架构、框架、流程、实施计划、验收矩阵、生产/安全/部署手册和其他多角色规范源。

### 7.1 审查前

1. 作者先完成充分、连贯的初稿；
2. 冻结规范源，记录 SHA-256、字节数、行数、稳定任务 ID 和冻结 Scope ID；
3. 建立 `Hermes_handoff`；
4. 由独立责任人制作脱敏副本并记录批准人/批准 ID。脚本不负责脱敏，规范源不得直接作为审查副本；
5. 运行预检。脚本会根据任务 ID、规范源路径和 Scope ID 在 `Hermes_handoff` 中建立唯一 append-only JSONL ledger；
6. Document QA 可提前校验，但若尚未登记，不阻塞第 1 轮；只有出现严重问题时才必须先获得有效 QA 责任角色。

同一任务＋规范源＋冻结范围最多三次真实调用。`review_started` 一旦写入即消耗一轮；调用失败、重试、修订、换报告名或换模型都不会退回次数。

### 7.2 执行第 1 轮

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

第 1 轮要求一次性报告所有合理可发现的重要问题。

`SERIOUS`：影响正确性、批准范围、可行性、安全/隐私、不可逆决策、失败处理、验收可测性或下游执行。

`NON_SERIOUS`：措辞、风格、可选增强或局部清晰度。登记为非阻塞 Open Issue，不触发反复修订。

脚本将严格解析报告头、严重问题数量和必需章节，并利用 `--usage-file` 校验真实模型。单次调用默认超时 600 秒（可在 30–3600 秒内显式设置）；超时也会消耗本轮。若模型返回内容但格式不合格，原始 stdout 只会保存为同名 `.rejected.md` 诊断证据，不会冒充正式报告。成功时依次输出 `HERMES_INVOCATION_PASS`、`HERMES_REPORT_VALIDATED`，再输出：

- `QA_DOCUMENT_REWORK`：存在严重问题且仍有剩余轮次；
- `DOCUMENT_REVIEW_LIMIT_REACHED`：第 3 轮仍有严重问题；
- `DOCUMENT_GATE_CANDIDATE`：自动报告满足候选条件，但尚未完成外部门禁。

### 7.3 Document QA 修订

- 将完整 `SERIOUS` 批次一次性交给已登记的 Document QA 任务；
- QA 只修改指定规范源和修订 ledger；
- QA 不能批准自己的修订；
- 总负责人不能替 QA 修文档；
- 返回新 SHA、精确 diff、逐 Finding 处理结果和验证证据。

### 7.4 第 2–3 轮

只验证严重问题修复和受影响回归，不重新进行审美式全文润色：

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

新发现的严重问题必须证明由修订引入，或第 1 轮无法合理发现。修改文件、换报告名、换任务、重试或新 SHA 都不会重置轮次。

第 3 轮后仍有严重问题，设置 `DOCUMENT_REVIEW_LIMIT_REACHED` 并请求用户决定；不得自动开始第 4 轮。

`DOCUMENT_GATE_CANDIDATE` 后，总负责人还必须核验实际模型、最终哈希、报告/metadata/ledger、无关 diff、非严重 Issue 所有者，以及**仅在发生 QA 修订时**核验 QA ledger。全部适用条件通过后才设置 `DOCUMENT_GATE_PASSED`，随后进入 `USER_CONFIRMATION_PENDING`。用户确认前不得启动下游实现。

## 8. Issue、阻塞和返工

- 普通缺陷：`REWORK_REQUIRED`，退回原产物责任角色；
- 凭据、平台或外部权限阻塞：`EXTERNAL_BLOCKED`；
- 上游未通过：`UPSTREAM_GATE_BLOCKED`；
- 任务不可用：`ROLE_THREAD_UNAVAILABLE`；
- 越权任务：`ROLE_BOUNDARY_BLOCKED`，不做 mutation；
- Hermes 不可用：`HERMES_REVIEW_BLOCKED`，不替换弱模型、不暴露敏感数据；
- 会话需要接续：`SESSION_RELAY_REQUIRED`。

阻塞记录必须包含：阻塞点、所有者、已尝试的安全检查、最小解除输入、恢复触发条件和唯一下一动作。阻塞是非终态，不等于允许越权，也不等于项目完成。

## 9. 验收与完成

`WORKFLOW_COMPLETE` 之前必须确认：

- 当前规范源和全部要求产物存在；
- 每项产物有责任角色自己的验证证据；
- 独立审核已经通过；
- 关键文档门禁通过；
- 阻塞 Open Issue 已关闭；
- 本地、集成、生产和人工验收分别满足；
- 用户/Boss 门禁满足；
- 连续性记录没有未完成门禁；
- 剩余风险明确标记为非阻塞并有所有者。

允许停止的唯一例外是用户明确说暂停、停止或取消，此时记录 `USER_PAUSED` 和用户原话。上下文压缩、客户端关闭或任务迁移不算停止授权。

## 10. 持久化记录模板

[contracts.md](references/contracts.md) 提供以下模板：

- Workflow ledger；
- Decision record；
- Role task packet；
- Critical-document record；
- Blocker/relay record；
- Acceptance record。

只有项目需要持久化证据时才建立记录，不要为了重复聊天内容制造文档。

## 11. 验证 Skill

```powershell
$env:PYTHONUTF8 = '1'
python "$HOME\.codex\skills\.system\skill-creator\scripts\quick_validate.py" .

pwsh -NoLogo -NoProfile -File .\tests\validate_lean_skill.ps1 -Path .
pwsh -NoLogo -NoProfile -File .\tests\run_scenarios.ps1 -Path .
pwsh -NoLogo -NoProfile -File .\tests\test_project_tools.ps1 -Path .
pwsh -NoLogo -NoProfile -File .\tests\test_review_critical_document.ps1 -Path .

# 会调用真实审核 API；只发送脚本生成的无敏感测试文本
pwsh -NoLogo -NoProfile -File .\tests\run_real_hermes_smoke.ps1 -Path .
```

该 smoke 不读取真实项目文档，也不占用真实项目的审查 ledger。若 Codex/桌面端沙箱阻止 Hermes 依赖的本地子进程（例如 Git Bash 文件读取器），主控必须先向用户申请本地执行权限，再原样重跑 smoke 或正式审查命令；不得自行关闭安全边界，也不得并行追加模型调用。

还应执行：

- PowerShell parser 检查；
- 项目结构初始化的 `Plan`/`Apply`、幂等、同名文件阻塞与扫描器代码识别测试；
- Hermes Preflight；
- mock Hermes 的路径冲突、真实模型、报告 schema、轮次 ledger、防覆盖测试；
- 发布前至少一次不含敏感数据的真实 Hermes 集成审查；
- Gitleaks 或 GitHub Secret Scanning；
- Git dirty state、提交 SHA 和远端 `main` SHA 对比。

关键词/结构校验只证明规则存在；行为测试才证明被覆盖场景的脚本行为。全部测试通过仍不自动证明使用该 Skill 的具体项目已经完成验收。

## 12. 发布更新

发布前：

1. 以当前安装版 Skill 为唯一源；
2. 逐文件同步到发布仓库；
3. README、LICENSE、`.gitignore` 只作为发布包装；
4. 比对 Skill 文件清单和原始对象哈希；
5. 运行全部验证；
6. 扫描密钥；
7. 检查精确 diff；
8. 提交并正常推送，不 force push；
9. 对比本地与远端 SHA；
10. 从远端原始 Git 对象再次确认文件一致。

## 13. 安全边界

- 不把 API Key、Token、Cookie、私钥或脱敏前文档放入仓库、报告、日志、截图或聊天；
- Hermes 只审查由独立责任人制作并明确批准的脱敏副本；脚本不会自动脱敏，也不会把规范源冒充为安全副本；
- 不因持续跟进而扩大部署、付款、发布、凭据、隐私或安全权限；
- 不因目录模板而擅自移动已有项目；
- 不因角色缺失而由总负责人代做；
- 不把本地测试、HTTP 200、构建成功或 Git push 当成生产/用户验收。

## 许可证

[MIT License](LICENSE)
