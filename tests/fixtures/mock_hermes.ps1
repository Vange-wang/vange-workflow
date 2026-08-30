$ErrorActionPreference = 'Stop'
$scriptArguments = @($args)

function Get-ArgumentValue([string]$Name) {
    $index = [Array]::IndexOf($scriptArguments, $Name)
    if ($index -lt 0 -or $index + 1 -ge $scriptArguments.Count) { return $null }
    return [string]$scriptArguments[$index + 1]
}

if ($args.Count -eq 1 -and $args[0] -eq '--version') {
    Write-Output 'Hermes Agent mock 1.0'
    return
}

if ($args.Count -eq 1 -and $args[0] -eq '--help') {
    Write-Output 'mock options: --oneshot --usage-file --model --toolsets --ignore-rules'
    return
}

if ($args.Count -ge 2 -and $args[0] -eq 'config' -and $args[1] -eq 'check') {
    Write-Output '✓ DEEPSEEK_API_KEY'
    Write-Output '✓ DEEPSEEK_BASE_URL'
    return
}

if ($args.Count -ge 2 -and $args[0] -eq 'profile' -and $args[1] -eq 'list') {
    $defaultModel = if ($env:VANGE_MOCK_DEFAULT_MODEL) { $env:VANGE_MOCK_DEFAULT_MODEL } else { 'deepseek-v4-pro' }
    if ($env:VANGE_MOCK_PROFILE_STATE_FILE -and (Test-Path -LiteralPath $env:VANGE_MOCK_PROFILE_STATE_FILE)) {
        $defaultModel = 'changed-default-model'
    }
    Write-Output "◆default $defaultModel"
    return
}

if ($args.Count -ge 2 -and $args[0] -eq 'fallback' -and $args[1] -eq 'list') {
    Write-Output 'No fallback providers configured.'
    return
}

if ([Array]::IndexOf($args, '--oneshot') -ge 0) {
    $prompt = Get-ArgumentValue '--oneshot'
    if ($prompt -notmatch 'relative file named: review-input\.md' -or $prompt -notmatch 'relative name "review-input\.md"') {
        [Console]::Error.WriteLine('Mock rejected a review prompt that did not constrain file access to the isolated relative input path.')
        exit 7
    }
    $usagePath = Get-ArgumentValue '--usage-file'
    $requestedModel = Get-ArgumentValue '--model'
    $actualModel = if ($env:VANGE_MOCK_ACTUAL_MODEL) { $env:VANGE_MOCK_ACTUAL_MODEL } else { $requestedModel }
    $usage = [ordered]@{
        estimated_cost_usd = 0
        cost_status = 'mock'
        input_tokens = 10
        output_tokens = 10
        total_tokens = 20
        api_calls = 1
        model = $actualModel
        provider = 'mock-provider'
        session_id = 'mock-session'
        completed = $true
        failed = $false
    }
    [IO.File]::WriteAllText($usagePath, ($usage | ConvertTo-Json -Depth 4), [Text.UTF8Encoding]::new($false))

    if ($env:VANGE_MOCK_CHANGE_DEFAULT -eq '1' -and $env:VANGE_MOCK_PROFILE_STATE_FILE) {
        [IO.File]::WriteAllText($env:VANGE_MOCK_PROFILE_STATE_FILE, 'changed', [Text.UTF8Encoding]::new($false))
    }

    if ($env:VANGE_MOCK_MALFORMED -eq '1') {
        Write-Output 'malformed review output'
        return
    }

    $verdict = if ($env:VANGE_MOCK_VERDICT) { $env:VANGE_MOCK_VERDICT } else { 'PASS_ZERO_ISSUES' }
    $serious = if ($env:VANGE_MOCK_SERIOUS) { [int]$env:VANGE_MOCK_SERIOUS } else { 0 }
    $nonSerious = if ($env:VANGE_MOCK_NON_SERIOUS) { [int]$env:VANGE_MOCK_NON_SERIOUS } else { 0 }
    if ($env:VANGE_MOCK_PREAMBLE -eq '1') { Write-Output 'Here is the requested review.' }
    Write-Output 'VANGE_REVIEW_SCHEMA: 1'
    Write-Output "VERDICT: $verdict"
    Write-Output "UNRESOLVED_SERIOUS: $serious"
    Write-Output "NON_SERIOUS_COUNT: $nonSerious"
    Write-Output '## Serious Findings'
    Write-Output $(if ($serious -gt 0) { 'S-001 | SERIOUS | mock material finding' } else { 'None.' })
    Write-Output '## Non-Serious Findings'
    Write-Output $(if ($nonSerious -gt 0) { 'N-001 | NON_SERIOUS | mock deferred item' } else { 'None.' })
    Write-Output '## Contradictions'
    Write-Output 'None.'
    Write-Output '## Missing Acceptance Criteria'
    Write-Output 'None.'
    Write-Output '## Remediation Checklist'
    Write-Output $(if ($serious -gt 0) { '- Resolve S-001.' } else { '- No serious remediation.' })
    Write-Output '## Open Issues'
    Write-Output $(if ($nonSerious -gt 0) { '- N-001: owner and trigger required.' } else { 'None.' })
    return
}

throw "Unsupported mock Hermes arguments: $($args -join ' ')"
