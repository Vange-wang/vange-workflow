param(
    [string]$Path = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $Path).Path
$failures = [System.Collections.Generic.List[string]]::new()

function Require-File([string]$RelativePath) {
    $full = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        $failures.Add("missing:$RelativePath")
        return $null
    }
    return $full
}

function Require-Match([string]$Text, [string]$Pattern, [string]$Label) {
    if ($Text -notmatch $Pattern) {
        $failures.Add("missing-rule:$Label")
    }
}

function Forbid-Match([string]$Text, [string]$Pattern, [string]$Label) {
    if ($Text -match $Pattern) {
        $failures.Add("duplicated-in-main:$Label")
    }
}

$skillPath = Require-File 'SKILL.md'
if ($null -ne $skillPath) {
    $skill = Get-Content -LiteralPath $skillPath -Raw -Encoding utf8
    $skillItem = Get-Item -LiteralPath $skillPath
    $lineCount = ($skill -split "`r?`n").Count

    if ($skillItem.Length -gt 11000) {
        $failures.Add("main-skill-too-large:bytes=$($skillItem.Length)>11000")
    }
    if ($lineCount -gt 150) {
        $failures.Add("main-skill-too-long:lines=$lineCount>150")
    }

    Require-Match $skill '(?i)THINK_BEFORE_ACTING' 'qualitative-thinking'
    Require-Match $skill '(?i)explicit.*(stop|pause|cancel)|明确.*(停止|暂停|取消)' 'explicit-pause-only'
    Require-Match $skill '(?i)lead.*(must not|does not).*(specialist|deliverable)|总负责人.*不得.*(专业|产物|代做)' 'lead-does-not-substitute'
    Require-Match $skill '(?i)(registered|登记|注册).*(thread|task|session|线程|任务)' 'registered-role-routing'
    Require-Match $skill '(?i)(subagent|子智能体).*(explicit|明确|授权|批准)' 'subagent-authorization'
    Require-Match $skill '(?i)(MAX_REVIEW_ROUNDS|at most three|最多三轮|three.*round)' 'three-round-cap'
    Require-Match $skill '(?i)SERIOUS.*(batch|批次)|严重.*(batch|批次)' 'serious-batch'
    Require-Match $skill '(?i)NON_SERIOUS.*(Open Issue|非阻塞)|非严重.*(Open Issue|非阻塞)' 'non-serious-defer'
    Require-Match $skill '(?i)WORKFLOW_COMPLETE' 'completion-state'
    Require-Match $skill '(?i)references/.*\.md' 'conditional-reference-routing'
    Require-Match $skill '(?i)project-repository-structure\.md' 'repository-structure-routing'

    Forbid-Match $skill '(?m)^## Route by Responsibility$' 'role-table'
    Forbid-Match $skill '(?m)^## Verification Ladder$' 'verification-ladder'
    Forbid-Match $skill '(?m)^## Context-Isolation Rules$' 'context-list'
    Forbid-Match $skill '(?m)^## Non-Terminal Blockers and Explicit Pause$' 'blocker-list'
    Forbid-Match $skill '(?m)^## Lead Completion Report$' 'completion-template'
}

$sizeLimits = @{
    'references/contracts.md' = 5200
    'references/critical-document-review.md' = 9000
    'references/thread-routing.md' = 5200
    'references/project-repository-structure.md' = 10000
    'references/user-invariants.md' = 4200
    'references/workflow-state-machine.md' = 4600
}

$structurePath = Require-File 'references/project-repository-structure.md'
if ($null -ne $structurePath) {
    $structure = Get-Content -LiteralPath $structurePath -Raw -Encoding utf8
    Require-Match $structure '(?i)Codex.*(primary|优先|主模板)' 'codex-structure-precedence'
    Require-Match $structure '(?i)WorkBuddy.*(supplement|补充)' 'workbuddy-supplement-only'
    Require-Match $structure '(?i)UI美术文档.*(optional|conditional|按需|条件)' 'optional-ui-directory'
    Require-Match $structure '(?i)(do not|不得|禁止).*(copy|复制).*(file|文件|content|内容)' 'no-sample-content-copy'
    Require-Match $structure '(?i)(report|报告).*(do not|不得|禁止).*(create|move|delete|创建|移动|删除)' 'report-only-structure-scan'
    Require-Match $structure '(?i)Hermes_handoff' 'single-hermes-handoff'
    Require-Match $structure '(?i)do not create generic per-role handoff' 'no-generic-role-handoff-tree'
    Require-Match $structure '(?i)Feature trigger registry' 'feature-trigger-registry'
    Require-Match $structure '(?i)zcode_tasks.*deliberately excluded' 'exclude-workbuddy-task-folders'
    Require-Match $structure '(?i)scanner (state )?covers.*core-path existence' 'scanner-coverage-boundary'
    Require-Match $structure '(?i)scan\.complete=true' 'scanner-completeness-gate'
}

foreach ($entry in $sizeLimits.GetEnumerator()) {
    $full = Require-File $entry.Key
    if ($null -ne $full) {
        $bytes = (Get-Item -LiteralPath $full).Length
        if ($bytes -gt $entry.Value) {
            $failures.Add("reference-too-large:$($entry.Key):bytes=$bytes>$($entry.Value)")
        }
    }
}

$reviewScript = Require-File 'scripts/review_critical_document.ps1'
if ($null -ne $reviewScript) {
    $scriptText = Get-Content -LiteralPath $reviewScript -Raw -Encoding utf8
    Require-Match $scriptText 'deepseek-v4-pro' 'review-model-override'
    Require-Match $scriptText 'Get-FileHash' 'review-source-hash'
    Require-Match $scriptText 'Copy-Item' 'review-copy-isolation'
    Require-Match $scriptText 'Preflight' 'review-preflight-mode'
    Require-Match $scriptText 'ReviewCopy' 'approved-review-copy-input'
    Require-Match $scriptText '--usage-file' 'actual-model-usage-proof'
    Require-Match $scriptText 'review_started' 'persistent-review-counter'
    Require-Match $scriptText 'FileMode\]::CreateNew' 'review-no-clobber-write'
    Require-Match $scriptText 'HERMES_INVOCATION_PASS' 'invocation-not-gate-marker'
    Forbid-Match $scriptText "Write-Output 'HERMES_REVIEW_PASS'" 'false-review-pass-marker'
}

$structureScript = Require-File 'scripts/initialize_project_structure.ps1'
if ($null -ne $structureScript) {
    $scriptText = Get-Content -LiteralPath $structureScript -Raw -Encoding utf8
    Require-Match $scriptText "ValidateSet\('Plan', 'Apply'\)" 'structure-plan-apply-modes'
    Require-Match $scriptText 'Hermes_handoff' 'structure-hermes-feature'
    Require-Match $scriptText '(?i)never moves, renames, or deletes' 'structure-create-only'
    Require-Match $scriptText '(?i)reparse point' 'structure-reparse-guard'
    Require-Match $scriptText '(?i)no directory was created' 'structure-preflight-before-apply'
    Forbid-Match $scriptText '(?i)任务与角色交接|WB_handoff|zcode_handoff' 'structure-generic-handoff'
}

$requiredStates = @(
    'WORKFLOW_ACTIVE',
    'WAITING_ROLE',
    'REWORK_REQUIRED',
    'ACCEPTANCE_PENDING',
    'EXTERNAL_BLOCKED',
    'SESSION_RELAY_REQUIRED',
    'USER_PAUSED',
    'WORKFLOW_COMPLETE',
    'HERMES_REVIEW_PENDING',
    'QA_DOCUMENT_REWORK',
    'DOCUMENT_REVIEW_LIMIT_REACHED'
    'DOCUMENT_GATE_CANDIDATE'
)

Require-File 'tests/test_project_tools.ps1' | Out-Null
Require-File 'tests/test_review_critical_document.ps1' | Out-Null
Require-File 'tests/run_real_hermes_smoke.ps1' | Out-Null
$allMarkdown = Get-ChildItem -LiteralPath $root -Recurse -Filter '*.md' -File |
    ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -Encoding utf8 } |
    Out-String
foreach ($state in $requiredStates) {
    if ($allMarkdown -notmatch [regex]::Escape($state)) {
        $failures.Add("missing-compatible-state:$state")
    }
}

$result = [ordered]@{
    root = $root
    failures = $failures.Count
    details = @($failures)
}

if ($failures.Count -gt 0) {
    $result | ConvertTo-Json -Depth 4
    exit 1
}

$result | ConvertTo-Json -Depth 4
Write-Output 'LEAN_SKILL_VALIDATION_PASS'
exit 0
