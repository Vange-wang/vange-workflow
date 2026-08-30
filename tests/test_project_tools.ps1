param(
    [string]$Path = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $Path).Path
$initializer = Join-Path $root 'scripts\initialize_project_structure.ps1'
$scanner = Join-Path $root 'scripts\project_intake.ps1'
$pwsh = (Get-Command pwsh -ErrorAction Stop).Source
$utf8NoBom = [Text.UTF8Encoding]::new($false)
$testRoot = Join-Path $env:TEMP ('vange-project-tools-' + [guid]::NewGuid())
$passed = [System.Collections.Generic.List[string]]::new()

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERTION_FAILED: $Message" }
}

function Invoke-Child([string[]]$Arguments) {
    $lines = @(& $pwsh @Arguments 2>&1)
    return [pscustomobject]@{
        exit_code = $LASTEXITCODE
        text = ($lines | ForEach-Object { [string]$_ }) -join "`n"
    }
}

try {
    [IO.Directory]::CreateDirectory($testRoot) | Out-Null

    $project = Join-Path $testRoot 'valid-project'
    [IO.Directory]::CreateDirectory($project) | Out-Null
    $plan = Invoke-Child @('-NoLogo', '-NoProfile', '-File', $initializer, '-Path', $project, '-Mode', 'Plan', '-Features', 'Code', '-Format', 'Json')
    Assert-True ($plan.exit_code -eq 0) "Plan failed: $($plan.text)"
    $planResult = $plan.text | ConvertFrom-Json
    Assert-True ($planResult.can_apply) 'Clean Plan must be applicable.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $project '规划文档'))) 'Plan must not create directories.'
    $passed.Add('plan-is-read-only')

    $apply = Invoke-Child @('-NoLogo', '-NoProfile', '-File', $initializer, '-Path', $project, '-Mode', 'Apply', '-Features', 'Code', '-Format', 'Json')
    Assert-True ($apply.exit_code -eq 0) "Apply failed: $($apply.text)"
    Assert-True (Test-Path -LiteralPath (Join-Path $project '规划文档') -PathType Container) 'Apply must create required roots.'
    Assert-True (Test-Path -LiteralPath (Join-Path $project 'Code文档') -PathType Container) 'Apply must create selected feature roots.'
    $passed.Add('apply-creates-selected-directories')

    $applyAgain = Invoke-Child @('-NoLogo', '-NoProfile', '-File', $initializer, '-Path', $project, '-Mode', 'Apply', '-Features', 'Code', '-Format', 'Json')
    Assert-True ($applyAgain.exit_code -eq 0) "Idempotent Apply failed: $($applyAgain.text)"
    $applyAgainResult = $applyAgain.text | ConvertFrom-Json
    Assert-True (@($applyAgainResult.entries | Where-Object { $_.created }).Count -eq 0) 'Second Apply must not recreate directories.'
    $passed.Add('apply-is-idempotent')

    $scriptOnlyProject = Join-Path $testRoot 'powershell-project'
    [IO.Directory]::CreateDirectory($scriptOnlyProject) | Out-Null
    [IO.File]::WriteAllText((Join-Path $scriptOnlyProject 'build.ps1'), "Write-Output 'ok'", $utf8NoBom)
    $scan = Invoke-Child @('-NoLogo', '-NoProfile', '-File', $scanner, '-Path', $scriptOnlyProject, '-Format', 'Json')
    Assert-True ($scan.exit_code -eq 0) "Scanner failed: $($scan.text)"
    $scanResult = $scan.text | ConvertFrom-Json
    $codeCheck = $scanResult.repository_structure.core | Where-Object { $_.path -eq 'Code文档' }
    Assert-True ($scanResult.scan.complete) 'Normal scan must report complete coverage.'
    Assert-True ($codeCheck.applies) 'A PowerShell-only project must be recognized as code-bearing.'
    Assert-True ($scanResult.repository_structure.status -eq 'STRUCTURE_REVIEW_REQUIRED') 'Missing code structure must require review.'
    $passed.Add('powershell-code-detected')

    $conflictProject = Join-Path $testRoot 'conflict-project'
    [IO.Directory]::CreateDirectory($conflictProject) | Out-Null
    [IO.File]::WriteAllText((Join-Path $conflictProject '规划文档'), 'conflict', $utf8NoBom)
    $conflict = Invoke-Child @('-NoLogo', '-NoProfile', '-File', $initializer, '-Path', $conflictProject, '-Mode', 'Apply', '-Format', 'Json')
    Assert-True ($conflict.exit_code -ne 0) 'Apply must fail when a file occupies a required directory path.'
    Assert-True ($conflict.text -match 'no directory was created') 'Conflict failure must prove preflight stopped mutation.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $conflictProject '协同工作文档'))) 'Conflict preflight must prevent partial structure creation.'
    $passed.Add('path-conflict-blocks-before-mutation')

    [pscustomobject]@{ passed = $passed.Count; scenarios = @($passed) } | ConvertTo-Json -Depth 4
    Write-Output "PROJECT_TOOLS_BEHAVIOR_PASS count=$($passed.Count)"
} finally {
    $tempBase = [IO.Path]::GetFullPath($env:TEMP).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $testFull = [IO.Path]::GetFullPath($testRoot)
    if ($testFull.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $testFull)) {
        Remove-Item -LiteralPath $testFull -Recurse -Force
    }
}
