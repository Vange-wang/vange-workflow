param(
    [ValidateSet('Preflight', 'Review')]
    [string]$Mode = 'Preflight',

    [string]$Source,

    [string]$Report,

    [ValidateRange(1, 3)]
    [int]$Round = 1
)

$ErrorActionPreference = 'Stop'

function Get-HermesPreflight {
    $command = Get-Command hermes -ErrorAction Stop
    $versionLines = @(& $command.Source --version 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Hermes version probe failed: $LASTEXITCODE"
    }

    $configLines = @(& $command.Source config check 2>&1)
    $configExit = $LASTEXITCODE
    $profileLines = @(& $command.Source profile list 2>&1)
    $profileExit = $LASTEXITCODE

    $configText = $configLines -join "`n"
    $profileText = $profileLines -join "`n"
    $defaultModel = $null
    if ($profileText -match '(?m)^\s*[◆*]?\s*default\s+(\S+)') {
        $defaultModel = $Matches[1]
    }

    [ordered]@{
        hermes_path = $command.Source
        version = if ($versionLines.Count -gt 0) { [string]$versionLines[0] } else { $null }
        config_exit_code = $configExit
        profile_exit_code = $profileExit
        deepseek_api_configured = $configText -match '✓\s+DEEPSEEK_API_KEY'
        deepseek_base_url_configured = $configText -match '✓\s+DEEPSEEK_BASE_URL'
        default_model = $defaultModel
        review_model = 'deepseek-v4-pro'
        default_model_changed = $false
    }
}

$preflight = Get-HermesPreflight

if ($Mode -eq 'Preflight') {
    $preflight | ConvertTo-Json -Depth 4
    if (
        $preflight.config_exit_code -ne 0 -or
        $preflight.profile_exit_code -ne 0 -or
        -not $preflight.deepseek_api_configured -or
        -not $preflight.deepseek_base_url_configured
    ) {
        exit 1
    }
    Write-Output 'HERMES_REVIEW_PREFLIGHT_PASS'
    exit 0
}

if ([string]::IsNullOrWhiteSpace($Source) -or [string]::IsNullOrWhiteSpace($Report)) {
    throw 'Review mode requires -Source and -Report.'
}
if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
    throw "Source document not found: $Source"
}
if (-not $preflight.deepseek_api_configured -or -not $preflight.deepseek_base_url_configured) {
    throw 'DeepSeek review configuration is incomplete.'
}

$sourcePath = (Resolve-Path -LiteralPath $Source).Path
$reportPath = [IO.Path]::GetFullPath($Report)
$reportDir = Split-Path -Parent $reportPath
if (-not (Test-Path -LiteralPath $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir | Out-Null
}

$beforeHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
$tempRoot = Join-Path $env:TEMP ('vange-hermes-review-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tempRoot | Out-Null
$reviewCopy = Join-Path $tempRoot ([IO.Path]::GetFileName($sourcePath))
Copy-Item -LiteralPath $sourcePath -Destination $reviewCopy

$prompt = @"
You are the independent read-only reviewer for a critical project document.
Review only this sanitized copy: $reviewCopy
Review round: $Round/3. Required invocation model: deepseek-v4-pro.

Think holistically before reporting. Round 1 must report all reasonably
discoverable material findings together. Later rounds verify serious fixes and
affected regressions; they must not reopen the document for stylistic polishing.

SERIOUS means material risk to correctness, approved scope, feasibility,
security/privacy, irreversible decisions, failure handling, acceptance/testability,
or downstream execution. NON_SERIOUS means wording, style, optional enhancement,
or local clarity without material ambiguity.

For every finding provide ID, severity, exact location, evidence, impact, and
correction or future closure trigger. Return Markdown with: metadata, round,
verdict, serious findings, non-serious findings, contradictions, missing
acceptance criteria, remediation checklist, and Open-Issue list.

Use REWORK_REQUIRED only when serious findings exist. Use PASS_ZERO_ISSUES when
nothing remains, or PASS_WITH_NONBLOCKING_OPEN_ISSUES when only non-serious
findings remain. Do not edit files or claim user approval.
"@

$startedAt = Get-Date
try {
    Push-Location $tempRoot
    try {
        $output = @(& $preflight.hermes_path --oneshot $prompt --model deepseek-v4-pro --toolsets file)
        $exitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    if ($exitCode -ne 0) {
        throw "Hermes review failed: $exitCode"
    }
    if ($output.Count -eq 0 -or [string]::IsNullOrWhiteSpace(($output -join ''))) {
        throw 'Hermes returned an empty report.'
    }

    [IO.File]::WriteAllText(
        $reportPath,
        ($output -join [Environment]::NewLine),
        [Text.UTF8Encoding]::new($false)
    )

    $afterHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    if ($afterHash -ne $beforeHash) {
        throw 'Canonical source changed during review.'
    }

    $metadata = [ordered]@{
        source = $sourcePath
        source_sha256 = $beforeHash
        report = $reportPath
        report_sha256 = (Get-FileHash -LiteralPath $reportPath -Algorithm SHA256).Hash
        round = "$Round/3"
        model = 'deepseek-v4-pro'
        hermes_path = $preflight.hermes_path
        hermes_version = $preflight.version
        default_model = $preflight.default_model
        default_model_changed = $false
        exit_code = $exitCode
        started_at = $startedAt.ToString('o')
        completed_at = (Get-Date).ToString('o')
        canonical_source_unchanged = $true
    }

    $metadataPath = $reportPath + '.metadata.json'
    [IO.File]::WriteAllText(
        $metadataPath,
        ($metadata | ConvertTo-Json -Depth 4),
        [Text.UTF8Encoding]::new($false)
    )
    $metadata | ConvertTo-Json -Depth 4
    Write-Output 'HERMES_REVIEW_PASS'
} finally {
    $tempFull = [IO.Path]::GetFullPath($tempRoot)
    $tempBase = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
    if (-not $tempFull.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove non-temporary path: $tempFull"
    }
    if (Test-Path -LiteralPath $tempFull) {
        Remove-Item -LiteralPath $tempFull -Recurse -Force
    }
}
