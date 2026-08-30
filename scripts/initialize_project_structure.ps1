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
$root = (Resolve-Path -LiteralPath $Path).Path.TrimEnd([IO.Path]::DirectorySeparatorChar)
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

function Test-PathWithin([string]$Child, [string]$Parent) {
    $relative = [IO.Path]::GetRelativePath($Parent, $Child)
    if ([IO.Path]::IsPathRooted($relative)) { return $false }
    return $relative -ne '..' -and -not $relative.StartsWith('..' + [IO.Path]::DirectorySeparatorChar)
}

function Get-ReparseComponent([string]$ProjectRoot, [string]$Target) {
    $rootItem = Get-Item -LiteralPath $ProjectRoot -Force
    if (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        return $rootItem.FullName
    }
    $relative = [IO.Path]::GetRelativePath($ProjectRoot, $Target)
    if ([IO.Path]::IsPathRooted($relative) -or $relative.StartsWith('..')) { return $null }
    $cursor = $ProjectRoot
    foreach ($segment in ($relative -split '[\\/]')) {
        if ([string]::IsNullOrWhiteSpace($segment) -or $segment -eq '.') { continue }
        $cursor = Join-Path $cursor $segment
        if (-not (Test-Path -LiteralPath $cursor)) { continue }
        $item = Get-Item -LiteralPath $cursor -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            return $item.FullName
        }
    }
    return $null
}

function Write-Result([System.Collections.IDictionary]$Result, [string]$OutputFormat) {
    if ($OutputFormat -eq 'Json') {
        $Result | ConvertTo-Json -Depth 6
        return
    }
    Write-Output "Root: $($Result.root)"
    Write-Output "Mode: $($Result.mode)"
    Write-Output "Features: $($Result.selected_features -join ', ')"
    Write-Output "Can apply: $($Result.can_apply)"
    foreach ($entry in $Result.entries) {
        Write-Output "$($entry.action): $($entry.relative_path)"
        if ($entry.blocker) { Write-Output "  blocker: $($entry.blocker)" }
    }
}

$selected = [System.Collections.Generic.List[string]]::new()
foreach ($relative in $required) {
    if (-not $selected.Contains($relative)) { $selected.Add($relative) }
}
foreach ($feature in $Features) {
    foreach ($relative in $featureMap[$feature]) {
        if (-not $selected.Contains($relative)) { $selected.Add($relative) }
    }
}

$entries = [System.Collections.Generic.List[object]]::new()
foreach ($relative in $selected) {
    $target = [IO.Path]::GetFullPath((Join-Path $root $relative))
    $insideRoot = Test-PathWithin $target $root
    $exists = Test-Path -LiteralPath $target
    $isDirectory = $exists -and (Test-Path -LiteralPath $target -PathType Container)
    $reparseComponent = if ($insideRoot) { Get-ReparseComponent $root $target } else { $null }
    $blocker = $null
    if (-not $insideRoot) {
        $blocker = "generated path escapes project root: $target"
    } elseif ($exists -and -not $isDirectory) {
        $blocker = "a non-directory item already occupies this path: $target"
    } elseif (-not [string]::IsNullOrWhiteSpace($reparseComponent)) {
        $blocker = "a symlink, junction, or reparse point is present in the target path: $reparseComponent"
    }

    $action = if ($blocker) {
        'blocked'
    } elseif ($isDirectory) {
        'keep'
    } elseif ($Mode -eq 'Apply') {
        'create'
    } else {
        'would_create'
    }

    $entries.Add([ordered]@{
        relative_path = $relative
        target = $target
        existed = $isDirectory
        action = $action
        created = $false
        blocker = $blocker
    })
}

$blockedEntries = @($entries | Where-Object { -not [string]::IsNullOrWhiteSpace($_.blocker) })
$result = [ordered]@{
    root = $root
    mode = $Mode
    selected_features = @($Features)
    mutation_authorized_by_script = $false
    can_apply = $blockedEntries.Count -eq 0
    blocker_count = $blockedEntries.Count
    rolled_back = $false
    rollback_warnings = @()
    note = 'Plan never mutates. Apply preflights every selected path, creates only missing directories, and never moves, renames, or deletes existing project content.'
    entries = $entries
}

if ($blockedEntries.Count -gt 0) {
    Write-Result $result $Format
    if ($Mode -eq 'Apply') {
        throw "STRUCTURE_APPLY_BLOCKED count=$($blockedEntries.Count); no directory was created."
    }
    exit 0
}

if ($Mode -eq 'Apply') {
    $createdPaths = [System.Collections.Generic.List[string]]::new()
    try {
        foreach ($entry in $entries) {
            if ($entry.action -ne 'create') { continue }
            [IO.Directory]::CreateDirectory($entry.target) | Out-Null
            $entry.created = $true
            $entry.action = 'created'
            $createdPaths.Add($entry.target)
        }
    } catch {
        $rollbackWarnings = [System.Collections.Generic.List[string]]::new()
        for ($index = $createdPaths.Count - 1; $index -ge 0; $index--) {
            $createdPath = $createdPaths[$index]
            try {
                if (
                    (Test-PathWithin $createdPath $root) -and
                    (Test-Path -LiteralPath $createdPath -PathType Container) -and
                    [string]::IsNullOrWhiteSpace((Get-ReparseComponent $root $createdPath))
                ) {
                    [IO.Directory]::Delete($createdPath, $false)
                }
            } catch {
                $rollbackWarnings.Add("Could not remove newly created empty directory '$createdPath': $($_.Exception.Message)")
            }
        }
        $result.rolled_back = $true
        $result.rollback_warnings = @($rollbackWarnings)
        throw "Structure initialization failed; newly created empty directories were rolled back where safe. Cause: $($_.Exception.Message)"
    }
}

Write-Result $result $Format
exit 0
