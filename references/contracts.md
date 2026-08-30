# Compact Records

Load only when a persistent dispatch, return, review, blocker, acceptance, or relay record is required. Omit fields that do not apply; do not create records merely to restate chat.

## Workflow ledger

```text
项目 / 总任务 ID：
当前状态：
目标与非目标：
已通过门禁与证据：
未通过门禁 / 阻塞 Open Issue：
活动角色 -> 注册线程 ID -> 当前动作：
精确下一动作与责任角色：
恢复触发条件：
连续性记录路径 / 最后更新时间：
用户是否明确暂停：否 / 是（附原话）
```

Use existing state names, including `WORKFLOW_ACTIVE`, `WAITING_ROLE`, `REWORK_REQUIRED`, `ACCEPTANCE_PENDING`, `EXTERNAL_BLOCKED`, `SESSION_RELAY_REQUIRED`, `USER_PAUSED`, and `WORKFLOW_COMPLETE`.

## Decision record

```text
规则：THINK_BEFORE_ACTING（定性就绪，不使用百分比、分数、时长或清单数量）
待决策事项：
目标 / 非目标 / 用户可见结果：
事实来源 / 冻结决策 / 关键假设：
角色 / 写入范围 / 依赖：
备选方案 / 取舍 / 长期影响：
失败、安全、隐私、回滚：
验收与证据计划：
可能改变决策的未知项：
行动批次：
就绪结论与依据：
```

## Role task packet

Use for dispatch, implementation handoff, rework, or boundary rejection.

```text
任务 ID / 执行角色 / 目标线程 ID：
目标与上游已确认结论：
输入与允许读取：
输出与唯一写入范围：
冻结范围 / 禁止事项：
验收标准 / 验证证据：
下游接收角色：
阻塞回报：状态 / 精确阻塞点 / 最小解除输入 / 恢复动作
完成回报：产物 / 修改 / 命令与结果 / 风险 / 建议门禁
```

Out-of-role return:

```text
状态：ROLE_BOUNDARY_BLOCKED
当前角色与线程 ID：
收到的越界任务 / 正确责任角色：
确认：未写文件、未运行 mutation、未修改其他角色记录
建议路由：
```

## Critical-document record

Use one evolving record across review, QA remediation, limit, and user confirmation.

```text
文档类型 / 规范源文件 / 作者角色：
冻结范围 / SHA-256 / 字节数 / 行数：
任务 ID / 冻结 Scope ID / review-cycle ledger：
审查轮次 n/3 / 已消耗与剩余次数：
独立审查副本 / SHA-256 / 脱敏批准人或批准 ID：
CLI 路径、版本、命令、请求模型、实际模型/provider、usage 证据、退出码：
报告与 metadata 路径 / SHA-256 / verdict：
SERIOUS 批次 / 未解决数：
NON_SERIOUS -> 非阻塞 Open Issue ID / 未来关闭触发条件：
如发生 QA：Document QA 线程 ID / 唯一写入文件 / 修订 ledger / 新 SHA-256：
无关 diff：
下一状态：HERMES_REVIEW_PENDING / QA_DOCUMENT_REWORK / DOCUMENT_REVIEW_LIMIT_REACHED / DOCUMENT_GATE_CANDIDATE / DOCUMENT_GATE_PASSED / USER_CONFIRMATION_PENDING
用户确认前禁止启动的下游工作：
```

At `DOCUMENT_REVIEW_LIMIT_REACHED`, include the remaining serious findings and the user choices: accept named risk, change scope, or authorize a new cycle after material scope/version change.

## Blocker or relay record

```text
状态：WAITING_ROLE / UPSTREAM_GATE_BLOCKED / EXTERNAL_BLOCKED / SESSION_RELAY_REQUIRED
总任务与不可变约束：
已完成阶段及证据：
当前门禁 / 精确阻塞点 / 所有者：
已尝试的安全检查：
当前可证明与不能声称的验收层级：
解除阻塞所需最小输入：
活动角色与注册线程 ID：
未完成项 / Open Issue：
恢复触发条件 / 唯一下一动作：
用户是否明确暂停：否 / 是（附原话）
```

## Acceptance record

```text
状态：ACCEPTANCE_PENDING / WORKFLOW_COMPLETE
结论：通过 / 有条件通过 / 不通过 / Blocked
验收范围 / 责任角色：
当前证据：
未满足项 / 是否阻塞下一步：
阻塞 Issue 的关闭证据：
本地 / 集成 / 生产 / 用户或 Boss 验收：
剩余非阻塞风险及所有者：
唯一下一动作：
```
