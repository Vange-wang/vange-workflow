[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [ValidateSet('Plan', 'Apply')]
    [string]$Mode = 'Plan',

    [ValidateSet('Code', 'Spec', 'Milestones', 'ProductIteration', 'TechnicalValidation', 'UI', 'DomainReferences', 'Hermes', 'DocumentQA', 'Communication', 'Notifications', 'SessionArchive', 'DecisionRecords', 'ReviewReports', 'AcceptanceClarification', 'CompletionReports', 'TechnicalNotes', 'EnvironmentValidation', 'SelfTestReports', 'Scripts', 'Tests', 'CodeDocs')]
    [string[]]$Features = @(),

    [ValidateSet('Text', 'Json')]
    [string]$Format = 'Text'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $Path).Path
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    throw "Project path is not a directory: $root"
}

$required = @(
    '规划文档',
    '协同工作文档',
    '协同工作文档\AGENT身份注册信息',
    '协同工作文档\ISSUE',
    '协同工作文档\ISSUE\Open_Issue',
    '协同工作文档\ISSUE\Close_Issue',
    '协同工作文档\ISSUE\Withdrawn_Issue',
    '协同工作文档\ISSUE\Issue_List',
    '总负责人文档',
    '总负责人文档\问题分析与任务预案'
)

$featureMap = [ordered]@{
    Code = @('Code文档')
    Spec = @('规划文档\Spec文档')
    Milestones = @('规划文档\里程碑文档')
    ProductIteration = @('规划文档\产品迭代')
    TechnicalValidation = @('规划文档\技术验证')
    UI = @('UI美术文档')
    DomainReferences = @('领域参考资料')
    Hermes = @('协同工作文档\Hermes_handoff')
    DocumentQA = @('协同工作文档\文档QA')
    Communication = @('协同工作文档\交流记录')
    Notifications = @('协同工作文档\通知与对齐')
    SessionArchive = @('协同工作文档\会话存档')
    DecisionRecords = @('协同工作文档\清单与裁决')
    ReviewReports = @('协同工作文档\审查报告')
    AcceptanceClarification = @('协同工作文档\验收与澄清')
    CompletionReports = @('协同工作文档\完成报告')
    TechnicalNotes = @('Code文档', 'Code文档\技术笔记')
    EnvironmentValidation = @('Code文档', 'Code文档\环境验证')
    SelfTestReports = @('Code文档', 'Code文档\自测报告')
    Scripts = @('Code文档', 'Code文档\scripts')
    Tests = @('Code文档', 'Code文档\tests')
    CodeDocs = @('Code文档', 'Code文档\docs')
}

$selected = [System.Collections.Generic.List[string]]::new()
foreach ($relative in $required) { if (-not $selected.Contains($relative)) { $selected.Add($relative) } }
foreach ($feature in $Features) {
    foreach ($relative in $featureMap[$feature]) {
        if (-not $selected.Contains($relative)) { $selected.Add($relative) }
    }
}

$entries = @()
foreach ($relative in $selected) {
    $target = [System.IO.Path]::GetFullPath((Join-Path $root $relative))
    if (-not $target.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Generated path escapes project root: $target"
    }
    $existsBefore = Test-Path -LiteralPath $target -PathType Container
    $created = $false
    if ($Mode -eq 'Apply' -and -not $existsBefore) {
        [System.IO.Directory]::CreateDirectory($target) | Out-Null
        $created = $true
    }
    $entries += [ordered]@{
        relative_path = $relative
        existed = $existsBefore
        action = $(if ($existsBefore) { 'keep' } elseif ($Mode -eq 'Apply') { 'create' } else { 'would_create' })
        created = $created
    }
}

$result = [ordered]@{
    root = $root
    mode = $Mode
    selected_features = @($Features)
    mutation_authorized_by_script = $false
    note = 'Apply only creates missing selected directories; it never moves, renames, or deletes.'
    entries = $entries
}

if ($Format -eq 'Json') {
    $result | ConvertTo-Json -Depth 5
    exit 0
}

Write-Output "Root: $root"
Write-Output "Mode: $Mode"
Write-Output "Features: $($Features -join ', ')"
foreach ($entry in $entries) {
    Write-Output "$($entry.action): $($entry.relative_path)"
}
exit 0
