param(
    [string]$Path = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $Path).Path
$reviewScript = Join-Path $root 'scripts\review_critical_document.ps1'
$mockHermes = Join-Path $root 'tests\fixtures\mock_hermes.ps1'
$pwsh = (Get-Command pwsh -ErrorAction Stop).Source
$utf8NoBom = [Text.UTF8Encoding]::new($false)
$testRoot = Join-Path $env:TEMP ('vange-review-tests-' + [guid]::NewGuid())
$passed = [System.Collections.Generic.List[string]]::new()

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERTION_FAILED: $Message" }
}

function New-Fixture([string]$Name, [bool]$SourceInsideHandoff = $false) {
    $fixtureRoot = Join-Path $testRoot $Name
    $handoff = Join-Path $fixtureRoot 'Hermes_handoff'
    [IO.Directory]::CreateDirectory($handoff) | Out-Null
    $source = if ($SourceInsideHandoff) { Join-Path $handoff 'canonical.md' } else { Join-Path $fixtureRoot 'canonical.md' }
    $copy = Join-Path $handoff 'approved-review-copy.md'
    [IO.File]::WriteAllText($source, '# Canonical`nNo restricted data in this test fixture.', $utf8NoBom)
    [IO.File]::WriteAllText($copy, '# Approved review copy`nNo restricted data.', $utf8NoBom)
    return [pscustomobject]@{ root = $fixtureRoot; handoff = $handoff; source = $source; copy = $copy }
}

function Invoke-Review(
    [object]$Fixture,
    [int]$Round,
    [string]$ReportName,
    [string]$TaskId = 'TASK-001',
    [string]$ScopeId = 'SCOPE-v1',
    [switch]$OmitSanitizationApproval
) {
    $report = Join-Path $Fixture.handoff $ReportName
    $arguments = @(
        '-NoLogo', '-NoProfile', '-File', $reviewScript,
        '-Mode', 'Review',
        '-Source', $Fixture.source,
        '-ReviewCopy', $Fixture.copy,
        '-HandoffDirectory', $Fixture.handoff,
        '-Report', $report,
        '-TaskId', $TaskId,
        '-ScopeId', $ScopeId,
        '-Round', [string]$Round,
        '-ReviewModel', 'deepseek-v4-pro',
        '-HermesPath', $mockHermes
    )
    if (-not $OmitSanitizationApproval) {
        $arguments += @('-SanitizationApprovedBy', 'test-approver')
    }
    $lines = @(& $pwsh @arguments 2>&1)
    return [pscustomobject]@{
        exit_code = $LASTEXITCODE
        text = ($lines | ForEach-Object { [string]$_ }) -join "`n"
        report = $report
    }
}

$savedEnvironment = @{}
$environmentNames = @(
    'VANGE_MOCK_ACTUAL_MODEL', 'VANGE_MOCK_DEFAULT_MODEL', 'VANGE_MOCK_CHANGE_DEFAULT',
    'VANGE_MOCK_PROFILE_STATE_FILE', 'VANGE_MOCK_MALFORMED', 'VANGE_MOCK_VERDICT',
    'VANGE_MOCK_SERIOUS', 'VANGE_MOCK_NON_SERIOUS'
)
foreach ($name in $environmentNames) { $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name) }

try {
    [IO.Directory]::CreateDirectory($testRoot) | Out-Null

    $alternativeWithoutApproval = @(& $pwsh '-NoLogo' '-NoProfile' '-File' $reviewScript '-Mode' 'Preflight' '-ReviewModel' 'approved-equivalent-model' '-HermesPath' $mockHermes 2>&1)
    Assert-True ($LASTEXITCODE -ne 0) 'Alternative reviewer model must require explicit approval and a capability basis.'
    $alternativeWithApproval = @(& $pwsh '-NoLogo' '-NoProfile' '-File' $reviewScript '-Mode' 'Preflight' '-ReviewModel' 'approved-equivalent-model' '-AlternativeModelApprovedBy' 'user-approval' '-CapabilityBasis' 'Independent review capability assessed as not materially weaker than lead, product, and QA.' '-HermesPath' $mockHermes 2>&1)
    Assert-True ($LASTEXITCODE -eq 0) "Approved alternative model preflight failed: $($alternativeWithApproval -join "`n")"
    $passed.Add('alternative-model-requires-approval-and-capability-basis')

    $missingApproval = New-Fixture 'missing-approval'
    $missingApprovalResult = Invoke-Review $missingApproval 1 'round-1.md' -OmitSanitizationApproval
    Assert-True ($missingApprovalResult.exit_code -ne 0) 'Review must reject a missing sanitization approval.'
    Assert-True (-not (Test-Path -LiteralPath $missingApprovalResult.report)) 'Rejected review must not create a report.'
    $passed.Add('missing-sanitization-approval-blocked')

    $collision = New-Fixture 'path-collision' $true
    $sourceBefore = (Get-FileHash -LiteralPath $collision.source -Algorithm SHA256).Hash
    $collisionArguments = @(
        '-NoLogo', '-NoProfile', '-File', $reviewScript,
        '-Mode', 'Review', '-Source', $collision.source, '-ReviewCopy', $collision.copy,
        '-HandoffDirectory', $collision.handoff, '-Report', $collision.source,
        '-TaskId', 'TASK-COLLISION', '-ScopeId', 'SCOPE-v1',
        '-SanitizationApprovedBy', 'test-approver', '-Round', '1',
        '-ReviewModel', 'deepseek-v4-pro', '-HermesPath', $mockHermes
    )
    $collisionOutput = @(& $pwsh @collisionArguments 2>&1)
    Assert-True ($LASTEXITCODE -ne 0) 'Source/report collision must fail.'
    Assert-True ((Get-FileHash -LiteralPath $collision.source -Algorithm SHA256).Hash -eq $sourceBefore) 'Collision failure must preserve the canonical source.'
    $passed.Add('source-report-collision-preserves-source')

    $valid = New-Fixture 'ledger-and-model'
    $round1 = Invoke-Review $valid 1 'round-1.md'
    Assert-True ($round1.exit_code -eq 0) "Valid round 1 failed: $($round1.text)"
    Assert-True ($round1.text -match 'HERMES_INVOCATION_PASS') 'Round 1 must report invocation success.'
    Assert-True ($round1.text -match 'HERMES_REPORT_VALIDATED') 'Round 1 must validate the report.'
    Assert-True ($round1.text -match 'DOCUMENT_GATE_CANDIDATE') 'Zero-issue report must be only a gate candidate.'
    Assert-True (Test-Path -LiteralPath $round1.report -PathType Leaf) 'Validated report must exist.'
    $metadata = Get-Content -LiteralPath ($round1.report + '.metadata.json') -Raw -Encoding utf8 | ConvertFrom-Json
    Assert-True ($metadata.actual_model -eq 'deepseek-v4-pro') 'Metadata must record the actual model from usage evidence.'
    Assert-True (-not $metadata.default_model_changed) 'Default model must be proven unchanged.'
    $passed.Add('valid-report-and-actual-model-evidence')

    $repeatRound1 = Invoke-Review $valid 1 'round-1-retry.md'
    Assert-True ($repeatRound1.exit_code -ne 0) 'A repeated round 1 must be rejected by the ledger.'
    Assert-True ($repeatRound1.text -match 'expected 2/3') 'Round mismatch must identify the next legal round.'
    $passed.Add('round-reuse-blocked')

    $env:VANGE_MOCK_ACTUAL_MODEL = 'weaker-fallback-model'
    $fallbackRound2 = Invoke-Review $valid 2 'round-2.md'
    Assert-True ($fallbackRound2.exit_code -ne 0) 'A runtime model mismatch must fail.'
    Assert-True ($fallbackRound2.text -match 'fallback is rejected') "Model mismatch must be labeled as rejected fallback. Actual output: $($fallbackRound2.text)"
    Assert-True (-not (Test-Path -LiteralPath $fallbackRound2.report)) 'Rejected fallback must not create a report.'
    $env:VANGE_MOCK_ACTUAL_MODEL = $null
    $passed.Add('silent-model-fallback-blocked')

    $env:VANGE_MOCK_VERDICT = 'REWORK_REQUIRED'
    $env:VANGE_MOCK_SERIOUS = '1'
    $round3 = Invoke-Review $valid 3 'round-3.md'
    Assert-True ($round3.exit_code -eq 0) "Round 3 serious report failed validation: $($round3.text)"
    Assert-True ($round3.text -match 'DOCUMENT_REVIEW_LIMIT_REACHED') 'Round 3 serious finding must stop the cycle.'
    $fourth = Invoke-Review $valid 3 'round-4.md'
    Assert-True ($fourth.exit_code -ne 0) 'A fourth invocation must be rejected.'
    Assert-True ($fourth.text -match 'already consumed three') 'Review limit rejection must cite the consumed budget.'
    $passed.Add('three-round-budget-enforced')
    $env:VANGE_MOCK_VERDICT = $null
    $env:VANGE_MOCK_SERIOUS = $null

    $malformed = New-Fixture 'malformed-report'
    $env:VANGE_MOCK_MALFORMED = '1'
    $malformedResult = Invoke-Review $malformed 1 'round-1.md'
    Assert-True ($malformedResult.exit_code -ne 0) 'Malformed report schema must fail.'
    Assert-True (-not (Test-Path -LiteralPath $malformedResult.report)) 'Malformed output must not become a report artifact.'
    $rejectedOutput = $malformedResult.report + '.rejected.md'
    Assert-True (Test-Path -LiteralPath $rejectedOutput -PathType Leaf) 'Rejected reviewer stdout must be retained separately for diagnosis.'
    Assert-True ((Get-Content -LiteralPath $rejectedOutput -Raw -Encoding utf8) -match 'malformed review output') 'Rejected-output evidence must contain the unpromoted reviewer stdout.'
    $env:VANGE_MOCK_MALFORMED = $null
    $passed.Add('malformed-report-schema-blocked')

    $preamble = New-Fixture 'preamble-before-schema'
    $env:VANGE_MOCK_PREAMBLE = '1'
    $preambleResult = Invoke-Review $preamble 1 'round-1.md'
    Assert-True ($preambleResult.exit_code -ne 0) 'A preamble before the machine header must fail validation.'
    Assert-True (-not (Test-Path -LiteralPath $preambleResult.report)) 'A preamble-bearing response must not become a formal report.'
    Assert-True ($preambleResult.text -match 'Preamble and reordered headers are rejected') 'The failure must identify the header-order contract.'
    $env:VANGE_MOCK_PREAMBLE = $null
    $passed.Add('machine-header-must-be-first')

    $changedDefault = New-Fixture 'default-model-change'
    $env:VANGE_MOCK_PROFILE_STATE_FILE = Join-Path $changedDefault.root 'profile-state.txt'
    $env:VANGE_MOCK_CHANGE_DEFAULT = '1'
    $changedDefaultResult = Invoke-Review $changedDefault 1 'round-1.md'
    Assert-True ($changedDefaultResult.exit_code -ne 0) 'Default-model mutation must fail the review.'
    Assert-True ($changedDefaultResult.text -match 'default model changed') 'Default-model mutation must be explicit in the failure.'
    Assert-True (-not (Test-Path -LiteralPath $changedDefaultResult.report)) 'Default-model mutation must not create a report.'
    $env:VANGE_MOCK_CHANGE_DEFAULT = $null
    $env:VANGE_MOCK_PROFILE_STATE_FILE = $null
    $passed.Add('default-model-mutation-blocked')

    $existing = New-Fixture 'no-clobber'
    $existingReport = Join-Path $existing.handoff 'round-1.md'
    [IO.File]::WriteAllText($existingReport, 'sentinel', $utf8NoBom)
    $existingResult = Invoke-Review $existing 1 'round-1.md'
    Assert-True ($existingResult.exit_code -ne 0) 'Existing report must not be overwritten.'
    Assert-True ((Get-Content -LiteralPath $existingReport -Raw -Encoding utf8) -eq 'sentinel') 'Existing report content must remain unchanged.'
    $passed.Add('existing-report-no-clobber')

    [pscustomobject]@{ passed = $passed.Count; scenarios = @($passed) } | ConvertTo-Json -Depth 4
    Write-Output "REVIEW_BEHAVIOR_PASS count=$($passed.Count)"
} finally {
    foreach ($name in $environmentNames) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name]) }
    $tempBase = [IO.Path]::GetFullPath($env:TEMP).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $testFull = [IO.Path]::GetFullPath($testRoot)
    if ($testFull.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $testFull)) {
        Remove-Item -LiteralPath $testFull -Recurse -Force
    }
}
