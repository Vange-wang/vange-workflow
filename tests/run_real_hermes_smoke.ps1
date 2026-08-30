param(
    [string]$Path = (Split-Path -Parent $PSScriptRoot),
    [string]$ReviewModel = 'deepseek-v4-pro'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $Path).Path
$reviewScript = Join-Path $root 'scripts\review_critical_document.ps1'
$pwsh = (Get-Command pwsh -ErrorAction Stop).Source
$testRoot = Join-Path $env:TEMP ('vange-real-hermes-smoke-' + [guid]::NewGuid())
$handoff = Join-Path $testRoot 'Hermes_handoff'
$source = Join-Path $testRoot 'canonical.md'
$reviewCopy = Join-Path $handoff 'approved-review-copy.md'
$report = Join-Path $handoff 'round-1.md'
$utf8NoBom = [Text.UTF8Encoding]::new($false)

try {
    [IO.Directory]::CreateDirectory($handoff) | Out-Null
    $fixture = @'
# Vange Workflow Integration Fixture

Purpose: verify the reviewer CLI transport, usage evidence, and report schema.

Scope: this generated text only. It contains no credentials, customer data, project files, or private information.

Acceptance:

1. The reviewer returns the required machine-readable headers and Markdown sections.
2. The usage report identifies the actual runtime model.
3. The canonical source and approved review copy remain unchanged.
'@
    [IO.File]::WriteAllText($source, $fixture, $utf8NoBom)
    [IO.File]::WriteAllText($reviewCopy, $fixture, $utf8NoBom)

    $arguments = @(
        '-NoLogo', '-NoProfile', '-File', $reviewScript,
        '-Mode', 'Review',
        '-Source', $source,
        '-ReviewCopy', $reviewCopy,
        '-HandoffDirectory', $handoff,
        '-Report', $report,
        '-TaskId', 'REAL-HERMES-SMOKE',
        '-ScopeId', 'TRANSPORT-SCHEMA-v1',
        '-SanitizationApprovedBy', 'generated-nonsensitive-test-fixture',
        '-Round', '1',
        '-ReviewModel', $ReviewModel
    )
    $lines = @(& $pwsh @arguments 2>&1)
    $text = ($lines | ForEach-Object { [string]$_ }) -join "`n"
    if ($LASTEXITCODE -ne 0) {
        $rejectedPath = $report + '.rejected.md'
        $rejectedEvidence = if (Test-Path -LiteralPath $rejectedPath -PathType Leaf) {
            $raw = Get-Content -LiteralPath $rejectedPath -Raw -Encoding utf8
            if ($raw.Length -gt 6000) { $raw.Substring(0, 6000) + "`n[truncated]" } else { $raw }
        } else {
            '[no rejected-output artifact]'
        }
        throw "Real Hermes smoke failed: $text`nRejected reviewer stdout:`n$rejectedEvidence"
    }
    if ($text -notmatch 'HERMES_REPORT_VALIDATED') { throw 'Real Hermes smoke did not validate the report.' }
    if (-not (Test-Path -LiteralPath $report -PathType Leaf)) { throw 'Real Hermes smoke report is missing.' }
    $metadata = Get-Content -LiteralPath ($report + '.metadata.json') -Raw -Encoding utf8 | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace([string]$metadata.actual_model)) { throw 'Actual model evidence is missing.' }
    if ($metadata.default_model_changed) { throw 'Default model changed during real smoke.' }

    [pscustomobject]@{
        actual_model = $metadata.actual_model
        provider = $metadata.actual_provider
        verdict = $metadata.verdict
        suggested_state = $metadata.suggested_state
        report_validated = $true
    } | ConvertTo-Json -Depth 4
    Write-Output 'REAL_HERMES_INTEGRATION_PASS'
} finally {
    $tempBase = [IO.Path]::GetFullPath($env:TEMP).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $testFull = [IO.Path]::GetFullPath($testRoot)
    if ($testFull.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $testFull)) {
        Remove-Item -LiteralPath $testFull -Recurse -Force
    }
}
