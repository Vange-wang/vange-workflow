[CmdletBinding()]
param(
    [ValidateSet('Preflight', 'Review')]
    [string]$Mode = 'Preflight',

    [string]$Source,

    [string]$ReviewCopy,

    [string]$Report,

    [string]$HandoffDirectory,

    [string]$TaskId,

    [string]$ScopeId,

    [string]$SanitizationApprovedBy,

    [ValidateRange(1, 3)]
    [int]$Round = 1,

    [string]$ReviewModel = 'deepseek-v4-pro',

    [string]$AlternativeModelApprovedBy,

    [string]$CapabilityBasis,

    [string]$HermesPath,

    [ValidateRange(30, 3600)]
    [int]$ReviewTimeoutSeconds = 600
)

$ErrorActionPreference = 'Stop'
$recommendedModel = 'deepseek-v4-pro'
$maxReviewRounds = 3
$utf8NoBom = [Text.UTF8Encoding]::new($false)

function Get-ModelLeaf([string]$Model) {
    if ([string]::IsNullOrWhiteSpace($Model)) { return $null }
    return (($Model.Trim() -split '/')[-1]).ToLowerInvariant()
}

function Get-NormalizedFullPath([string]$Path) {
    return [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
}

function Test-PathWithin([string]$Child, [string]$Parent) {
    $relative = [IO.Path]::GetRelativePath($Parent, $Child)
    if ([IO.Path]::IsPathRooted($relative)) { return $false }
    return $relative -ne '..' -and -not $relative.StartsWith('..' + [IO.Path]::DirectorySeparatorChar)
}

function Assert-NoReparsePointInPath([string]$Path, [string]$Label) {
    $cursor = if (Test-Path -LiteralPath $Path) { Get-NormalizedFullPath $Path } else { Split-Path -Parent (Get-NormalizedFullPath $Path) }
    while (-not [string]::IsNullOrWhiteSpace($cursor)) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "$Label must not traverse a symlink, junction, or other reparse point: $($item.FullName)"
            }
        }
        $parent = Split-Path -Parent $cursor
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $cursor) { break }
        $cursor = $parent
    }
}

function Assert-DistinctPaths([hashtable]$Paths) {
    $seen = @{}
    foreach ($entry in $Paths.GetEnumerator()) {
        $key = (Get-NormalizedFullPath $entry.Value).ToLowerInvariant()
        if ($seen.ContainsKey($key)) {
            throw "Path collision: $($entry.Key) and $($seen[$key]) resolve to the same path."
        }
        $seen[$key] = $entry.Key
    }
}

function Get-StableSha256([string]$Text) {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
        return -join ($algorithm.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') })
    } finally {
        $algorithm.Dispose()
    }
}

function Invoke-HermesCommand(
    [string]$Executable,
    [string[]]$Arguments,
    [int]$TimeoutSeconds = 60
) {
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    if ([IO.Path]::GetExtension($Executable) -ieq '.ps1') {
        $startInfo.FileName = (Get-Command pwsh -ErrorAction Stop).Source
        foreach ($prefixArgument in @('-NoLogo', '-NoProfile', '-File', $Executable)) {
            $startInfo.ArgumentList.Add($prefixArgument)
        }
    } else {
        $startInfo.FileName = $Executable
    }
    foreach ($argument in $Arguments) { $startInfo.ArgumentList.Add([string]$argument) }
    $startInfo.UseShellExecute = $false
    # A console-less pwsh child replaces non-ASCII output with '?'. The process
    # inherits this console, writes only to redirected streams, and opens no new UI.
    $startInfo.CreateNoWindow = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) { throw 'Hermes process could not be started.' }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $completed = $process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $completed) {
            try { $process.Kill($true) } catch { $process.Kill() }
            $process.WaitForExit()
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        return [pscustomobject]@{
            exit_code = if ($completed) { [int]$process.ExitCode } else { -1 }
            timed_out = -not $completed
            stdout = [string]$stdout
            stderr = [string]$stderr
            lines = @(([string]$stdout -split "`r?`n") | Where-Object { $_ -ne '' })
        }
    } finally {
        $process.Dispose()
    }
}

function Resolve-HermesExecutable([string]$ExplicitPath) {
    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        if (-not (Test-Path -LiteralPath $ExplicitPath -PathType Leaf)) {
            throw "HERMES_REVIEW_BLOCKED: Hermes executable not found: $ExplicitPath"
        }
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }

    $command = Get-Command hermes -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw 'HERMES_REVIEW_BLOCKED: Hermes CLI is unavailable. A desktop controller must obtain explicit user approval before installing a reviewer CLI. If no CLI can be used, request authorization for a separate independent review task.'
    }
    return $command.Source
}

function Get-HermesPreflight([string]$Executable, [string]$RequestedModel) {
    $version = Invoke-HermesCommand $Executable @('--version')
    if ($version.exit_code -ne 0) {
        throw "Hermes version probe failed: $($version.exit_code)"
    }

    $help = Invoke-HermesCommand $Executable @('--help')
    $config = Invoke-HermesCommand $Executable @('config', 'check')
    $profile = Invoke-HermesCommand $Executable @('profile', 'list')
    $fallback = Invoke-HermesCommand $Executable @('fallback', 'list')

    $configText = $config.lines -join "`n"
    $profileText = $profile.lines -join "`n"
    $fallbackText = $fallback.lines -join "`n"
    $helpText = $help.lines -join "`n"
    $defaultModel = $null
    if ($profileText -match '(?m)^\s*[◆*]?\s*default\s+(\S+)') {
        $defaultModel = $Matches[1]
    }

    return [ordered]@{
        hermes_path = $Executable
        version = if ($version.lines.Count -gt 0) { [string]$version.lines[0] } else { $null }
        help_exit_code = $help.exit_code
        config_exit_code = $config.exit_code
        profile_exit_code = $profile.exit_code
        fallback_exit_code = $fallback.exit_code
        supports_usage_file = $helpText -match '(?m)--usage-file'
        deepseek_api_configured = $configText -match '✓\s+DEEPSEEK_API_KEY'
        deepseek_base_url_configured = $configText -match '✓\s+DEEPSEEK_BASE_URL'
        default_model = $defaultModel
        requested_review_model = $RequestedModel
        fallback_configured = $fallback.exit_code -eq 0 -and $fallbackText -notmatch '(?i)No fallback providers configured'
        default_model_change_checked = $false
    }
}

function Assert-ModelPolicy(
    [string]$RequestedModel,
    [string]$ApprovedBy,
    [string]$Basis
) {
    if ((Get-ModelLeaf $RequestedModel) -eq (Get-ModelLeaf $recommendedModel)) { return }
    if ([string]::IsNullOrWhiteSpace($ApprovedBy) -or [string]::IsNullOrWhiteSpace($Basis)) {
        throw "HERMES_REVIEW_BLOCKED: $recommendedModel is recommended. An alternative model requires explicit user approval and a recorded capability basis showing it is not materially weaker than the product manager, project lead, and independent QA roles."
    }
}

function Assert-UsablePreflight([System.Collections.IDictionary]$Preflight, [string]$RequestedModel) {
    if (
        $Preflight.help_exit_code -ne 0 -or
        $Preflight.config_exit_code -ne 0 -or
        $Preflight.profile_exit_code -ne 0 -or
        -not $Preflight.supports_usage_file
    ) {
        throw 'HERMES_REVIEW_BLOCKED: Hermes preflight failed or this CLI cannot emit an actual-model usage report.'
    }
    if (
        (Get-ModelLeaf $RequestedModel) -eq (Get-ModelLeaf $recommendedModel) -and
        (-not $Preflight.deepseek_api_configured -or -not $Preflight.deepseek_base_url_configured)
    ) {
        throw 'HERMES_REVIEW_BLOCKED: DeepSeek review configuration is incomplete.'
    }
}

function Read-LedgerRecords([IO.FileStream]$Stream) {
    $Stream.Position = 0
    $reader = [IO.StreamReader]::new($Stream, [Text.UTF8Encoding]::new($false), $true, 4096, $true)
    try {
        $text = $reader.ReadToEnd()
    } finally {
        $reader.Dispose()
    }

    $records = [System.Collections.Generic.List[object]]::new()
    foreach ($line in ($text -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $records.Add(($line | ConvertFrom-Json))
        } catch {
            throw "Review ledger contains invalid JSONL and cannot be trusted: $($_.Exception.Message)"
        }
    }
    return @($records)
}

function Add-LedgerRecord([IO.FileStream]$Stream, [System.Collections.IDictionary]$Record) {
    $json = ($Record | ConvertTo-Json -Depth 8 -Compress) + [Environment]::NewLine
    $bytes = $utf8NoBom.GetBytes($json)
    $Stream.Position = $Stream.Length
    $Stream.Write($bytes, 0, $bytes.Length)
    $Stream.Flush($true)
}

function Get-UniqueHeaderValue([string]$Text, [string]$Name) {
    $pattern = '(?im)^\s*' + [regex]::Escape($Name) + '\s*:\s*(.+?)\s*$'
    $matches = [regex]::Matches($Text, $pattern)
    if ($matches.Count -ne 1) {
        throw "Hermes report must contain exactly one '${Name}:' header."
    }
    return $matches[0].Groups[1].Value.Trim()
}

function Get-ValidatedVerdict([string]$Text) {
    $nonEmptyLines = @($Text -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $requiredPrefix = @('VANGE_REVIEW_SCHEMA', 'VERDICT', 'UNRESOLVED_SERIOUS', 'NON_SERIOUS_COUNT')
    if ($nonEmptyLines.Count -lt $requiredPrefix.Count) {
        throw 'Hermes report is too short to contain the required four-line machine header.'
    }
    for ($index = 0; $index -lt $requiredPrefix.Count; $index++) {
        if ($nonEmptyLines[$index] -notmatch ('^\s*' + [regex]::Escape($requiredPrefix[$index]) + '\s*:')) {
            throw "Hermes report line $($index + 1) must begin with '$($requiredPrefix[$index]):'. Preamble and reordered headers are rejected."
        }
    }

    $schema = Get-UniqueHeaderValue $Text 'VANGE_REVIEW_SCHEMA'
    $verdict = Get-UniqueHeaderValue $Text 'VERDICT'
    $seriousText = Get-UniqueHeaderValue $Text 'UNRESOLVED_SERIOUS'
    $nonSeriousText = Get-UniqueHeaderValue $Text 'NON_SERIOUS_COUNT'

    if ($schema -ne '1') { throw "Unsupported review report schema: $schema" }
    $allowedVerdicts = @('REWORK_REQUIRED', 'PASS_ZERO_ISSUES', 'PASS_WITH_NONBLOCKING_OPEN_ISSUES')
    if ($verdict -notin $allowedVerdicts) { throw "Invalid Hermes verdict: $verdict" }

    $serious = 0
    $nonSerious = 0
    if (-not [int]::TryParse($seriousText, [ref]$serious) -or $serious -lt 0) {
        throw 'UNRESOLVED_SERIOUS must be a non-negative integer.'
    }
    if (-not [int]::TryParse($nonSeriousText, [ref]$nonSerious) -or $nonSerious -lt 0) {
        throw 'NON_SERIOUS_COUNT must be a non-negative integer.'
    }

    $requiredSections = @(
        'Serious Findings',
        'Non-Serious Findings',
        'Contradictions',
        'Missing Acceptance Criteria',
        'Remediation Checklist',
        'Open Issues'
    )
    foreach ($section in $requiredSections) {
        if ($Text -notmatch ('(?im)^#{1,6}\s+' + [regex]::Escape($section) + '\s*$')) {
            throw "Hermes report is missing required section: $section"
        }
    }

    if ($verdict -eq 'REWORK_REQUIRED' -and $serious -eq 0) {
        throw 'REWORK_REQUIRED requires at least one unresolved serious finding.'
    }
    if ($verdict -ne 'REWORK_REQUIRED' -and $serious -ne 0) {
        throw 'A pass verdict requires zero unresolved serious findings.'
    }
    if ($verdict -eq 'PASS_ZERO_ISSUES' -and $nonSerious -ne 0) {
        throw 'PASS_ZERO_ISSUES requires NON_SERIOUS_COUNT=0.'
    }
    if ($verdict -eq 'PASS_WITH_NONBLOCKING_OPEN_ISSUES' -and $nonSerious -eq 0) {
        throw 'PASS_WITH_NONBLOCKING_OPEN_ISSUES requires at least one non-serious finding.'
    }

    return [ordered]@{
        verdict = $verdict
        unresolved_serious = $serious
        non_serious_count = $nonSerious
    }
}

function Write-NewUtf8File([string]$Path, [string]$Content) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $bytes = $utf8NoBom.GetBytes($Content)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
    } finally {
        $stream.Dispose()
    }
}

Assert-ModelPolicy $ReviewModel $AlternativeModelApprovedBy $CapabilityBasis
$hermesExecutable = Resolve-HermesExecutable $HermesPath
$preflightBefore = Get-HermesPreflight $hermesExecutable $ReviewModel
Assert-UsablePreflight $preflightBefore $ReviewModel

if ($Mode -eq 'Preflight') {
    $preflightBefore | ConvertTo-Json -Depth 5
    Write-Output 'HERMES_REVIEW_PREFLIGHT_PASS'
    exit 0
}

$requiredReviewValues = [ordered]@{
    Source = $Source
    ReviewCopy = $ReviewCopy
    Report = $Report
    HandoffDirectory = $HandoffDirectory
    TaskId = $TaskId
    ScopeId = $ScopeId
    SanitizationApprovedBy = $SanitizationApprovedBy
}
foreach ($entry in $requiredReviewValues.GetEnumerator()) {
    if ([string]::IsNullOrWhiteSpace([string]$entry.Value)) {
        throw "Review mode requires -$($entry.Key)."
    }
}

foreach ($pathEntry in @($Source, $ReviewCopy, $Report, $HandoffDirectory)) {
    if (-not [IO.Path]::IsPathFullyQualified($pathEntry)) {
        throw "Review paths must be absolute: $pathEntry"
    }
}
if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
    throw "Canonical source document not found: $Source"
}
if (-not (Test-Path -LiteralPath $ReviewCopy -PathType Leaf)) {
    throw "Approved sanitized review copy not found: $ReviewCopy"
}
if (-not (Test-Path -LiteralPath $HandoffDirectory -PathType Container)) {
    throw "Hermes handoff directory not found: $HandoffDirectory"
}

$sourcePath = (Resolve-Path -LiteralPath $Source).Path
$reviewCopyPath = (Resolve-Path -LiteralPath $ReviewCopy).Path
$handoffPath = (Resolve-Path -LiteralPath $HandoffDirectory).Path.TrimEnd([IO.Path]::DirectorySeparatorChar)
$reportPath = Get-NormalizedFullPath $Report
$reportDirectory = Split-Path -Parent $reportPath
if (-not (Test-Path -LiteralPath $reportDirectory -PathType Container)) {
    throw "Report directory must already exist: $reportDirectory"
}
if (-not (Test-PathWithin $reviewCopyPath $handoffPath)) {
    throw 'The approved sanitized review copy must be inside the Hermes handoff directory.'
}
if (-not (Test-PathWithin $reportPath $handoffPath)) {
    throw 'The report must be written inside the Hermes handoff directory.'
}

Assert-NoReparsePointInPath $sourcePath 'Canonical source'
Assert-NoReparsePointInPath $handoffPath 'Handoff directory'
Assert-NoReparsePointInPath $reviewCopyPath 'Review copy'
Assert-NoReparsePointInPath $reportDirectory 'Report directory'

$cycleMaterial = "$($sourcePath.ToLowerInvariant())`n$TaskId`n$ScopeId"
$cycleId = Get-StableSha256 $cycleMaterial
$ledgerPath = Join-Path $handoffPath ("review-cycle-$cycleId.jsonl")
$metadataPath = $reportPath + '.metadata.json'
$rejectedOutputPath = $reportPath + '.rejected.md'

Assert-DistinctPaths @{
    Source = $sourcePath
    ReviewCopy = $reviewCopyPath
    Report = $reportPath
    Metadata = $metadataPath
    RejectedOutput = $rejectedOutputPath
    Ledger = $ledgerPath
}
if (Test-Path -LiteralPath $reportPath) {
    throw "Refusing to overwrite an existing review report: $reportPath"
}
if (Test-Path -LiteralPath $metadataPath) {
    throw "Refusing to overwrite existing review metadata: $metadataPath"
}
if (Test-Path -LiteralPath $rejectedOutputPath) {
    throw "Refusing to overwrite existing rejected-output evidence: $rejectedOutputPath"
}

$beforeSourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
$beforeReviewCopyHash = (Get-FileHash -LiteralPath $reviewCopyPath -Algorithm SHA256).Hash
$ledgerStream = $null
$tempRoot = $null
$roundStarted = $false
$roundCompleted = $false
$startedAt = Get-Date

try {
    $ledgerStream = [IO.File]::Open(
        $ledgerPath,
        [IO.FileMode]::OpenOrCreate,
        [IO.FileAccess]::ReadWrite,
        [IO.FileShare]::Read
    )
    $records = @(Read-LedgerRecords $ledgerStream)
    if ($records.Count -eq 0) {
        if ($Round -ne 1) {
            throw 'A new review cycle must start at round 1.'
        }
        Add-LedgerRecord $ledgerStream ([ordered]@{
            event = 'cycle_initialized'
            schema = 1
            cycle_id = $cycleId
            task_id = $TaskId
            scope_id = $ScopeId
            canonical_source = $sourcePath
            max_review_rounds = $maxReviewRounds
            initialized_at = (Get-Date).ToString('o')
        })
        $records = @(Read-LedgerRecords $ledgerStream)
    }

    $cycleRecords = @($records | Where-Object { $_.event -eq 'cycle_initialized' })
    if ($cycleRecords.Count -ne 1) {
        throw 'Review ledger must contain exactly one cycle_initialized record.'
    }
    $cycle = $cycleRecords[0]
    if (
        [string]$cycle.cycle_id -ne $cycleId -or
        [string]$cycle.task_id -ne $TaskId -or
        [string]$cycle.scope_id -ne $ScopeId -or
        -not ([string]$cycle.canonical_source).Equals($sourcePath, [StringComparison]::OrdinalIgnoreCase) -or
        [int]$cycle.max_review_rounds -ne $maxReviewRounds
    ) {
        throw 'Review ledger identity does not match the task, canonical source, or frozen scope.'
    }

    $consumedRounds = @($records | Where-Object { $_.event -eq 'review_started' }).Count
    if ($consumedRounds -ge $maxReviewRounds) {
        throw 'DOCUMENT_REVIEW_LIMIT_REACHED: this task + canonical document + frozen scope already consumed three review invocations.'
    }
    $expectedRound = $consumedRounds + 1
    if ($Round -ne $expectedRound) {
        throw "Review round mismatch: expected $expectedRound/3, received $Round/3. Retries and edits do not reset the counter."
    }
    if (@($records | Where-Object { $_.report -and ([string]$_.report).Equals($reportPath, [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0) {
        throw 'Each review invocation requires a new report path; prior round evidence cannot be replaced.'
    }

    Add-LedgerRecord $ledgerStream ([ordered]@{
        event = 'review_started'
        cycle_id = $cycleId
        round = $Round
        canonical_source_sha256 = $beforeSourceHash
        review_copy_sha256 = $beforeReviewCopyHash
        sanitization_approved_by = $SanitizationApprovedBy
        requested_model = $ReviewModel
        alternative_model_approved_by = $AlternativeModelApprovedBy
        capability_basis = $CapabilityBasis
        report = $reportPath
        review_timeout_seconds = $ReviewTimeoutSeconds
        started_at = $startedAt.ToString('o')
    })
    $roundStarted = $true

    $tempRoot = Join-Path $env:TEMP ('vange-hermes-review-' + [guid]::NewGuid())
    [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
    $reviewExtension = [IO.Path]::GetExtension($reviewCopyPath)
    if ([string]::IsNullOrWhiteSpace($reviewExtension) -or $reviewExtension -notmatch '^\.[A-Za-z0-9]{1,12}$') {
        $reviewExtension = '.txt'
    }
    $isolatedReviewName = 'review-input' + $reviewExtension.ToLowerInvariant()
    $isolatedReviewCopy = Join-Path $tempRoot $isolatedReviewName
    Copy-Item -LiteralPath $reviewCopyPath -Destination $isolatedReviewCopy
    $isolatedBeforeHash = (Get-FileHash -LiteralPath $isolatedReviewCopy -Algorithm SHA256).Hash
    $usagePath = Join-Path $tempRoot 'hermes-usage.json'

    $prompt = @"
OUTPUT CONTRACT — FOLLOW BEFORE ALL OTHER INSTRUCTIONS:
Return no preamble and no fenced code block. The first four non-empty output
lines must be these four fields, with one permitted value replacing each token:
VANGE_REVIEW_SCHEMA: 1
VERDICT: REWORK_REQUIRED or PASS_ZERO_ISSUES or PASS_WITH_NONBLOCKING_OPEN_ISSUES
UNRESOLVED_SERIOUS: a non-negative integer
NON_SERIOUS_COUNT: a non-negative integer

You are the independent read-only reviewer for a critical project document.
Review only the owner-approved sanitized relative file named: $isolatedReviewName
The process working directory already contains that file. Pass exactly the
relative name "$isolatedReviewName" to read_file; do not use an absolute path.
Do not edit any file. Canonical source SHA-256: $beforeSourceHash
Approved review-copy SHA-256: $beforeReviewCopyHash
Review round: $Round/3. Requested invocation model: $ReviewModel.

Think holistically before reporting. Round 1 must report all reasonably
discoverable material findings together. Later rounds verify serious fixes and
affected regressions; they must not reopen the document for stylistic polishing.

SERIOUS means material risk to correctness, approved scope, feasibility,
security/privacy, irreversible decisions, failure handling, acceptance/testability,
or downstream execution. NON_SERIOUS means wording, style, optional enhancement,
or local clarity without material ambiguity.

After the four required fields, return Markdown sections named exactly: Serious Findings, Non-Serious
Findings, Contradictions, Missing Acceptance Criteria, Remediation Checklist,
and Open Issues. For every finding provide ID, severity, exact location,
evidence, impact, and correction or future closure trigger. Round 1 must not
drip-feed reasonably discoverable serious issues.

Use REWORK_REQUIRED only when serious findings exist. Use PASS_ZERO_ISSUES when
nothing remains, or PASS_WITH_NONBLOCKING_OPEN_ISSUES when only non-serious
findings remain. Do not claim user approval or final project acceptance.

FINAL FORMAT CHECK: your response must begin with VANGE_REVIEW_SCHEMA: 1,
followed immediately by VERDICT, UNRESOLVED_SERIOUS, and NON_SERIOUS_COUNT.
"@

    Push-Location $tempRoot
    try {
        $invocation = Invoke-HermesCommand -Executable $hermesExecutable -Arguments @(
            '--oneshot', $prompt,
            '--usage-file', $usagePath,
            '--model', $ReviewModel,
            '--toolsets', 'file',
            '--ignore-rules'
        ) -TimeoutSeconds $ReviewTimeoutSeconds
    } finally {
        Pop-Location
    }

    if ($invocation.timed_out) {
        throw "Hermes review timed out after $ReviewTimeoutSeconds seconds. The invocation consumed this review round."
    }
    if ($invocation.exit_code -ne 0) {
        throw "Hermes review invocation failed: $($invocation.exit_code)"
    }
    $outputText = $invocation.stdout.Trim()
    if ([string]::IsNullOrWhiteSpace($outputText)) {
        throw 'Hermes returned an empty report.'
    }
    if (-not (Test-Path -LiteralPath $usagePath -PathType Leaf)) {
        throw 'Hermes did not emit the required usage report; actual model cannot be proven.'
    }

    $usage = Get-Content -LiteralPath $usagePath -Raw -Encoding utf8 | ConvertFrom-Json
    if ($usage.failed -or -not $usage.completed -or [int]$usage.api_calls -lt 1) {
        throw 'Hermes usage evidence does not prove a completed model invocation.'
    }
    if ((Get-ModelLeaf ([string]$usage.model)) -ne (Get-ModelLeaf $ReviewModel)) {
        throw "HERMES_REVIEW_BLOCKED: requested model '$ReviewModel' but runtime reported '$($usage.model)'. Silent fallback is rejected."
    }

    $preflightAfter = Get-HermesPreflight $hermesExecutable $ReviewModel
    Assert-UsablePreflight $preflightAfter $ReviewModel
    $defaultModelChanged = -not ([string]$preflightBefore.default_model).Equals(
        [string]$preflightAfter.default_model,
        [StringComparison]::OrdinalIgnoreCase
    )
    if ($defaultModelChanged) {
        throw 'HERMES_REVIEW_BLOCKED: Hermes default model changed during the invocation.'
    }

    $afterSourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    $afterReviewCopyHash = (Get-FileHash -LiteralPath $reviewCopyPath -Algorithm SHA256).Hash
    $isolatedAfterHash = (Get-FileHash -LiteralPath $isolatedReviewCopy -Algorithm SHA256).Hash
    if ($afterSourceHash -ne $beforeSourceHash) {
        throw 'Canonical source changed during review.'
    }
    if ($afterReviewCopyHash -ne $beforeReviewCopyHash) {
        throw 'Approved review copy changed during review.'
    }
    if ($isolatedAfterHash -ne $isolatedBeforeHash) {
        throw 'Hermes modified the isolated review copy; read-only review cannot be proven.'
    }

    try {
        $parsed = Get-ValidatedVerdict $outputText
    } catch {
        $schemaFailure = $_.Exception.Message
        Write-NewUtf8File $rejectedOutputPath ($outputText + [Environment]::NewLine)
        throw "Hermes report schema invalid. Rejected reviewer stdout was preserved without promoting it to the formal report: $rejectedOutputPath. Cause: $schemaFailure"
    }
    $suggestedState = if ($parsed.unresolved_serious -gt 0) {
        if ($Round -eq $maxReviewRounds) { 'DOCUMENT_REVIEW_LIMIT_REACHED' } else { 'QA_DOCUMENT_REWORK' }
    } else {
        'DOCUMENT_GATE_CANDIDATE'
    }

    $metadata = [ordered]@{
        schema = 2
        cycle_id = $cycleId
        task_id = $TaskId
        scope_id = $ScopeId
        canonical_source = $sourcePath
        canonical_source_sha256 = $beforeSourceHash
        approved_review_copy = $reviewCopyPath
        approved_review_copy_sha256 = $beforeReviewCopyHash
        sanitization_approved_by = $SanitizationApprovedBy
        report = $reportPath
        ledger = $ledgerPath
        round = "$Round/$maxReviewRounds"
        requested_model = $ReviewModel
        actual_model = [string]$usage.model
        actual_provider = [string]$usage.provider
        api_calls = [int]$usage.api_calls
        usage_completed = [bool]$usage.completed
        hermes_path = $hermesExecutable
        hermes_version = $preflightBefore.version
        default_model_before = $preflightBefore.default_model
        default_model_after = $preflightAfter.default_model
        default_model_changed = $defaultModelChanged
        fallback_configured = $preflightBefore.fallback_configured
        verdict = $parsed.verdict
        unresolved_serious = $parsed.unresolved_serious
        non_serious_count = $parsed.non_serious_count
        suggested_state = $suggestedState
        invocation_exit_code = $invocation.exit_code
        review_timeout_seconds = $ReviewTimeoutSeconds
        started_at = $startedAt.ToString('o')
        completed_at = (Get-Date).ToString('o')
        canonical_source_unchanged = $true
        approved_review_copy_unchanged = $true
        isolated_review_copy_unchanged = $true
    }

    Write-NewUtf8File $reportPath ($outputText + [Environment]::NewLine)
    Write-NewUtf8File $metadataPath (($metadata | ConvertTo-Json -Depth 8) + [Environment]::NewLine)

    $finalSourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    $finalReviewCopyHash = (Get-FileHash -LiteralPath $reviewCopyPath -Algorithm SHA256).Hash
    if ($finalSourceHash -ne $beforeSourceHash -or $finalReviewCopyHash -ne $beforeReviewCopyHash) {
        throw 'Protected document changed while review artifacts were being written.'
    }

    Add-LedgerRecord $ledgerStream ([ordered]@{
        event = 'review_completed'
        cycle_id = $cycleId
        round = $Round
        requested_model = $ReviewModel
        actual_model = [string]$usage.model
        actual_provider = [string]$usage.provider
        report = $reportPath
        report_sha256 = (Get-FileHash -LiteralPath $reportPath -Algorithm SHA256).Hash
        metadata = $metadataPath
        metadata_sha256 = (Get-FileHash -LiteralPath $metadataPath -Algorithm SHA256).Hash
        verdict = $parsed.verdict
        unresolved_serious = $parsed.unresolved_serious
        non_serious_count = $parsed.non_serious_count
        suggested_state = $suggestedState
        completed_at = (Get-Date).ToString('o')
    })
    $roundCompleted = $true

    $metadata | ConvertTo-Json -Depth 8
    Write-Output 'HERMES_INVOCATION_PASS'
    Write-Output 'HERMES_REPORT_VALIDATED'
    Write-Output $suggestedState
} catch {
    if ($roundStarted -and -not $roundCompleted -and $null -ne $ledgerStream) {
        try {
            Add-LedgerRecord $ledgerStream ([ordered]@{
                event = 'review_failed'
                cycle_id = $cycleId
                round = $Round
                report = $reportPath
                rejected_output = if (Test-Path -LiteralPath $rejectedOutputPath -PathType Leaf) { $rejectedOutputPath } else { $null }
                failure = $_.Exception.Message
                failed_at = (Get-Date).ToString('o')
            })
        } catch {
            Write-Warning 'The review failed and the failure record could not be appended to the ledger.'
        }
    }
    throw
} finally {
    if ($null -ne $ledgerStream) { $ledgerStream.Dispose() }
    if (-not [string]::IsNullOrWhiteSpace($tempRoot) -and (Test-Path -LiteralPath $tempRoot)) {
        $tempFull = [IO.Path]::GetFullPath($tempRoot)
        $tempBase = [IO.Path]::GetFullPath($env:TEMP).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        if (-not $tempFull.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove non-temporary path: $tempFull"
        }
        Remove-Item -LiteralPath $tempFull -Recurse -Force
    }
}
