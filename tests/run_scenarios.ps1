param(
    [string]$Path = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $Path).Path
$skill = Get-Content -LiteralPath (Join-Path $root 'SKILL.md') -Raw -Encoding utf8
$routing = Get-Content -LiteralPath (Join-Path $root 'references\thread-routing.md') -Raw -Encoding utf8
$review = Get-Content -LiteralPath (Join-Path $root 'references\critical-document-review.md') -Raw -Encoding utf8
$states = Get-Content -LiteralPath (Join-Path $root 'references\workflow-state-machine.md') -Raw -Encoding utf8
$verification = Get-Content -LiteralPath (Join-Path $root 'references\verification-matrix.md') -Raw -Encoding utf8
$repositoryStructure = Get-Content -LiteralPath (Join-Path $root 'references\project-repository-structure.md') -Raw -Encoding utf8

$results = [System.Collections.Generic.List[object]]::new()

function Add-Scenario(
    [string]$Name,
    [string]$ExpectedState,
    [string]$ExpectedOwner,
    [string]$ExpectedAction,
    [bool]$Pass,
    [string]$Evidence
) {
    $results.Add([pscustomobject]@{
        scenario = $Name
        expected_state = $ExpectedState
        expected_owner = $ExpectedOwner
        expected_action = $ExpectedAction
        pass = $Pass
        evidence = $Evidence
    })
}

$rolePass =
    $skill -match 'lead must not create specialist deliverables' -and
    $routing -match 'ROLE_BOUNDARY_BLOCKED' -and
    $routing -match 'identify the correct owner'
Add-Scenario `
    -Name 'lead-receives-specialist-code-task' `
    -ExpectedState 'ROLE_BOUNDARY_BLOCKED' `
    -ExpectedOwner 'registered specialist' `
    -ExpectedAction 'return without mutation and route the bounded packet' `
    -Pass $rolePass `
    -Evidence 'main invariant + routing failure-state contract'

$blockerPass =
    $skill -match 'If blocked, exhaust safe read-only checks' -and
    $states -match 'EXTERNAL_BLOCKED' -and
    $states -match 'non-terminal'
Add-Scenario `
    -Name 'credential-blocks-next-step' `
    -ExpectedState 'EXTERNAL_BLOCKED' `
    -ExpectedOwner 'credential or external authority owner' `
    -ExpectedAction 'record minimum unblock input and resume trigger; do not claim completion' `
    -Pass $blockerPass `
    -Evidence 'main blocker rule + state compatibility'

$reviewPass =
    $skill -match 'MAX_REVIEW_ROUNDS = 3' -and
    $review -match 'Round 1.*all reasonably discoverable material findings' -and
    $review -match 'complete serious-finding batch' -and
    $review -match 'NON_SERIOUS.*non-blocking Open Issue' -and
    $review -match 'After round 3'
Add-Scenario `
    -Name 'critical-document-round-one-has-mixed-findings' `
    -ExpectedState 'QA_DOCUMENT_REWORK' `
    -ExpectedOwner 'Document QA for one serious batch; Issue manager for non-serious items' `
    -ExpectedAction 'preserve 1/3 counter; re-review only after QA returns' `
    -Pass $reviewPass `
    -Evidence 'main critical branch + bounded review reference'

$completionPass =
    $skill -match 'WORKFLOW_COMPLETE.*requires all applicable' -and
    $states -match 'ACCEPTANCE_PENDING' -and
    $verification -match 'A local pass never implies production acceptance|local preflight clearly labeled' -and
    $skill -match 'integration, production, and human gates are reported separately'
Add-Scenario `
    -Name 'local-tests-pass-production-and-user-gates-pending' `
    -ExpectedState 'ACCEPTANCE_PENDING' `
    -ExpectedOwner 'named independent or user approver' `
    -ExpectedAction 'continue to production/human gate; do not set WORKFLOW_COMPLETE' `
    -Pass $completionPass `
    -Evidence 'completion predicate + state + verification matrix'

$structurePass =
    $repositoryStructure -match 'Codex.*(primary|优先|主模板)' -and
    $repositoryStructure -match 'WorkBuddy.*(supplement|补充)' -and
    $repositoryStructure -match 'UI美术文档.*(optional|conditional|按需|条件)' -and
    $repositoryStructure -match '(do not|不得|禁止).*(copy|复制).*(file|文件|content|内容)' -and
    $repositoryStructure -match 'only `Hermes_handoff`' -and
    $repositoryStructure -notmatch '任务与角色交接'
Add-Scenario `
    -Name 'codex-and-workbuddy-structures-conflict' `
    -ExpectedState 'WORKFLOW_ACTIVE' `
    -ExpectedOwner 'project lead for structure governance' `
    -ExpectedAction 'keep the Codex structure and add only non-conflicting WorkBuddy responsibilities; do not create optional UI folders without need' `
    -Pass $structurePass `
    -Evidence 'repository structure precedence and conditional-directory contract'

$failures = @($results | Where-Object { -not $_.pass })
$results | ConvertTo-Json -Depth 4
if ($failures.Count -gt 0) {
    Write-Error "SCENARIO_CONTRACT_FAIL count=$($failures.Count)"
    exit 1
}

Write-Output "SCENARIO_CONTRACT_PASS count=$($results.Count)"
exit 0
