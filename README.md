# Vange Workflow

Vange Workflow 是当前实际用于 Codex 项目的多角色协作 Skill。此仓库发布内容以正在使用的 `vange-workflow` 为唯一规范源，仅面向 Codex＋Hermes CLI 协作方式。

## 当前协作方式

- 主控与固定项目角色运行在 Codex 的已登记任务中。
- 项目总负责人只负责路由、持续跟进、证据检查、门禁和收口，不代做专业角色产物。
- 关键文档由 Hermes CLI 以 `deepseek-v4-pro` 独立只读审查；严重问题批量交给独立 Document QA 修订。
- 同一任务、规范文档和冻结范围最多审查三轮；非严重问题登记为非阻塞 Open Issue。
- 工作流在全部适用验收通过前保持活动；只有用户明确暂停、停止或取消才停止。

完整行为规则以 [SKILL.md](SKILL.md) 为准。

## 安装

将仓库克隆到 Codex Skills 目录，并保持目录名为 `vange-workflow`：

```powershell
git clone https://github.com/Vange-wang/vange-workflow.git "$HOME\.codex\skills\vange-workflow"
```

重新打开 Codex 任务后即可发现该 Skill。

## 关键文档审查预检

本版本要求本机已经安装并配置 Hermes CLI 与 DeepSeek 接口。预检不会修改 Hermes 默认模型：

```powershell
pwsh -NoLogo -NoProfile -File .\scripts\review_critical_document.ps1 -Mode Preflight
```

正式审查只对脱敏临时副本执行，并在单次调用中指定 `deepseek-v4-pro`：

```powershell
pwsh -NoLogo -NoProfile -File .\scripts\review_critical_document.ps1 `
  -Mode Review `
  -Source <absolute-document-path> `
  -Report <absolute-report-path> `
  -Round <1|2|3>
```

## 验证

```powershell
pwsh -NoLogo -NoProfile -File .\tests\validate_lean_skill.ps1 -Path .
pwsh -NoLogo -NoProfile -File .\tests\run_scenarios.ps1 -Path .
```

发布前还应使用 Gitleaks 或 GitHub Secret Scanning 检查凭据泄露。

## 许可证

[MIT License](LICENSE)
