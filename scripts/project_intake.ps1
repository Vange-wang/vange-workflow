[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [ValidateSet('Text', 'Json')]
    [string]$Format = 'Text'
)

$ErrorActionPreference = 'Stop'
$resolved = Resolve-Path -LiteralPath $Path
$root = $resolved.Path
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    throw "Project path is not a directory: $root"
}

$scanComplete = $true
$scanEngine = 'rg'
$scanDiagnostics = [System.Collections.Generic.List[string]]::new()
$useFallback = $false
$rg = Get-Command rg -ErrorAction SilentlyContinue

if ($null -ne $rg) {
    $allFiles = @(& $rg.Source --files --hidden `
        --glob '!**/.git/**' `
        --glob '!**/.worktrees/**' `
        --glob '!**/node_modules/**' `
        --glob '!**/.venv*/**' `
        --glob '!**/venv/**' `
        --glob '!**/.next/**' `
        --glob '!**/dist/**' `
        --glob '!**/build/**' `
        --glob '!**/*.png' `
        --glob '!**/*.jpg' `
        --glob '!**/*.jpeg' `
        --glob '!**/*.gif' `
        --glob '!**/*.mp4' `
        --glob '!**/*.mov' `
        --glob '!**/*.webm' `
        --glob '!**/*.wav' `
        --glob '!**/*.mp3' `
        --glob '!**/*.zip' `
        $root 2>$null)
    $rgExitCode = $LASTEXITCODE
    if ($rgExitCode -gt 1) {
        $scanDiagnostics.Add("rg file enumeration failed with exit code $rgExitCode; fallback enumeration was used.")
        $useFallback = $true
    }
} else {
    $scanDiagnostics.Add('rg is unavailable; fallback enumeration was used.')
    $useFallback = $true
}

if ($useFallback) {
    $scanEngine = 'GetChildItem'
    $enumerationErrors = @()
    $allFiles = @(Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue -ErrorVariable +enumerationErrors |
        Where-Object {
            $_.FullName -notmatch '[\/](\.git|\.worktrees|node_modules|\.venv[^\/]*|venv|\.next|dist|build)[\/]' -and
            $_.Extension -notmatch '(?i)^\.(png|jpe?g|gif|mp4|mov|webm|wav|mp3|zip)$'
        } |
        Select-Object -ExpandProperty FullName)
    if ($enumerationErrors.Count -gt 0) {
        $scanComplete = $false
        $scanDiagnostics.Add("Fallback enumeration encountered $($enumerationErrors.Count) filesystem error(s); coverage is incomplete.")
    }
}

$allFiles = @($allFiles | ForEach-Object { [string]$_ } | Sort-Object -Unique)

$entryDocs = @($allFiles | Where-Object {
    $name = [IO.Path]::GetFileName($_)
    $name -eq 'AGENTS.md' -or $name -eq 'CONTEXT.md' -or $name -like 'README*'
} | Sort-Object)

$sourceDocs = @($allFiles | Where-Object {
    $name = [IO.Path]::GetFileName($_)
    $extension = [IO.Path]::GetExtension($_)
    $name -match '(?i)prd|spec|需求|规范|架构|设计|工作流|流程|协议|里程碑|验收|安全|部署|runbook|复盘|方案' -and
        $extension -match '(?i)^\.(md|mdx|txt|docx|pdf)$'
} | Sort-Object)

$manifestNames = @(
    'package.json', 'pyproject.toml', 'setup.py', 'setup.cfg', 'pipfile', 'poetry.lock',
    'cargo.toml', 'go.mod', 'pom.xml', 'build.gradle', 'build.gradle.kts',
    'settings.gradle', 'settings.gradle.kts', 'cmakelists.txt', 'makefile', 'meson.build',
    'composer.json', 'gemfile', 'pubspec.yaml', 'package.swift', 'mix.exs', 'rebar.config',
    'platformio.ini', 'idf_component.yml'
)
$manifests = @($allFiles | Where-Object {
    $name = [IO.Path]::GetFileName($_).ToLowerInvariant()
    $name -in $manifestNames -or $name -like 'requirements*.txt' -or $name -match '\.(csproj|fsproj|vbproj|sln)$'
} | Sort-Object)

$codeExtensions = @(
    '.astro', '.bat', '.c', '.cc', '.clj', '.cljs', '.cmd', '.cpp', '.cs', '.dart',
    '.erl', '.ex', '.exs', '.fs', '.fsx', '.go', '.gradle', '.groovy', '.h', '.hpp',
    '.hrl', '.ino', '.java', '.js', '.jsx', '.kt', '.kts', '.lua', '.m', '.mm',
    '.nim', '.php', '.pl', '.pm', '.proto', '.ps1', '.psd1', '.psm1', '.py', '.r',
    '.rb', '.rs', '.scala', '.sh', '.sol', '.sql', '.svelte', '.swift', '.tf', '.ts',
    '.tsx', '.vb', '.vue', '.zig'
)
$codeIndicators = @($allFiles | Where-Object {
    $codeExtensions -contains [IO.Path]::GetExtension($_).ToLowerInvariant()
})

$openIssues = @($allFiles | Where-Object { $_ -match '[\\/]Open_Issue[\\/].+\.md$' -and $_ -notmatch '[\\/]README\.md$' })
$closedIssues = @($allFiles | Where-Object { $_ -match '[\\/]Close_Issue[\\/].+\.md$' -and $_ -notmatch '[\\/]README\.md$' })
$issueTables = @($allFiles | Where-Object {
    $name = [IO.Path]::GetFileName($_)
    $name -ieq 'ISSUE总表.md' -or $name -match '(?i)^issue.*list.*\.md$'
} | Sort-Object)

$threadRegistryFiles = @($allFiles | Where-Object {
    $name = [IO.Path]::GetFileName($_)
    $name -like '*.md' -and (
        $_ -match '[\\/]AGENT身份注册信息[\\/]' -or
        $name -match '(?i)注册状态总览|子智能体注册表|身份注册|钦定'
    )
} | Sort-Object)

$threadIdPattern = '(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b'
$threadIdCandidates = @()
foreach ($registryFile in $threadRegistryFiles) {
    try {
        $registryText = Get-Content -LiteralPath $registryFile -Raw -Encoding utf8
        $ids = @([regex]::Matches($registryText, $threadIdPattern) | ForEach-Object { $_.Value.ToLowerInvariant() } | Sort-Object -Unique)
        if ($ids.Count -gt 0) {
            $threadIdCandidates += [ordered]@{ file = $registryFile; ids = $ids }
        }
    } catch {
        $threadIdCandidates += [ordered]@{ file = $registryFile; parse_error = $_.Exception.Message; ids = @() }
        $scanComplete = $false
        $scanDiagnostics.Add("Could not parse a role registry file: $registryFile")
    }
}

$verificationScripts = [ordered]@{}
foreach ($manifest in ($manifests | Where-Object { [IO.Path]::GetFileName($_) -eq 'package.json' })) {
    try {
        $package = Get-Content -LiteralPath $manifest -Raw -Encoding utf8 | ConvertFrom-Json
        if ($null -ne $package.scripts) {
            $selectedScripts = [ordered]@{}
            foreach ($property in $package.scripts.PSObject.Properties) {
                if ($property.Name -match '(?i)test|typecheck|lint|build|verify|check|inspect|render|preflight|smoke') {
                    $selectedScripts[$property.Name] = [string]$property.Value
                }
            }
            if ($selectedScripts.Count -gt 0) { $verificationScripts[$manifest] = $selectedScripts }
        }
    } catch {
        $verificationScripts[$manifest] = [ordered]@{ parse_error = $_.Exception.Message }
    }
}

$gitMarkerExists = Test-Path -LiteralPath (Join-Path $root '.git')
$isGit = $false
$gitRoot = $null
$branch = $null
$dirtyEntries = @()
$gitCommand = Get-Command git -ErrorAction SilentlyContinue
if ($null -ne $gitCommand) {
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $probe = @(& $gitCommand.Source -C $root rev-parse --is-inside-work-tree 2>&1)
    $probeExit = $LASTEXITCODE
    if ($probeExit -eq 0 -and ($probe | Select-Object -First 1) -eq 'true') {
        $isGit = $true
        $gitRoot = (& $gitCommand.Source -C $root rev-parse --show-toplevel 2>$null | Select-Object -First 1)
        $branch = (& $gitCommand.Source -C $root branch --show-current 2>$null | Select-Object -First 1)
        $dirtyEntries = @(& $gitCommand.Source -C $root status --short -- . 2>$null)
    }
    $ErrorActionPreference = $savedPreference
}

$topLevelErrors = @()
$topLevel = @(Get-ChildItem -LiteralPath $root -Force -ErrorAction SilentlyContinue -ErrorVariable +topLevelErrors |
    Sort-Object Name |
    Select-Object -First 30 |
    ForEach-Object {
        $kind = if ($_.PSIsContainer) { 'dir' } else { 'file' }
        [ordered]@{ name = $_.Name; kind = $kind }
    })
if ($topLevelErrors.Count -gt 0) {
    $scanComplete = $false
    $scanDiagnostics.Add("Top-level enumeration encountered $($topLevelErrors.Count) filesystem error(s); coverage is incomplete.")
}

function Test-ProjectDirectory([string]$RelativePath) {
    return Test-Path -LiteralPath (Join-Path $root $RelativePath) -PathType Container
}

$codeApplicable = $codeIndicators.Count -gt 0 -or $manifests.Count -gt 0 -or (Test-ProjectDirectory 'Code文档')
$coreDirectoryChecks = @(
    [ordered]@{ path = '规划文档'; applies = $true; exists = (Test-ProjectDirectory '规划文档'); reason = 'structured project planning source' },
    [ordered]@{ path = '协同工作文档'; applies = $true; exists = (Test-ProjectDirectory '协同工作文档'); reason = 'multi-role coordination records' },
    [ordered]@{ path = '协同工作文档\AGENT身份注册信息'; applies = $true; exists = (Test-ProjectDirectory '协同工作文档\AGENT身份注册信息'); reason = 'Codex registered-role bindings and work records' },
    [ordered]@{ path = '协同工作文档\ISSUE\Open_Issue'; applies = $true; exists = (Test-ProjectDirectory '协同工作文档\ISSUE\Open_Issue'); reason = 'open Issue state' },
    [ordered]@{ path = '协同工作文档\ISSUE\Close_Issue'; applies = $true; exists = (Test-ProjectDirectory '协同工作文档\ISSUE\Close_Issue'); reason = 'closed Issue state' },
    [ordered]@{ path = '协同工作文档\ISSUE\Withdrawn_Issue'; applies = $true; exists = (Test-ProjectDirectory '协同工作文档\ISSUE\Withdrawn_Issue'); reason = 'withdrawn Issue state' },
    [ordered]@{ path = '协同工作文档\ISSUE\Issue_List'; applies = $true; exists = (Test-ProjectDirectory '协同工作文档\ISSUE\Issue_List'); reason = 'canonical Issue list' },
    [ordered]@{ path = '总负责人文档'; applies = $true; exists = (Test-ProjectDirectory '总负责人文档'); reason = 'lead responsibility root' },
    [ordered]@{ path = '总负责人文档\问题分析与任务预案'; applies = $true; exists = (Test-ProjectDirectory '总负责人文档\问题分析与任务预案'); reason = 'lead analysis and task plans' },
    [ordered]@{ path = 'Code文档'; applies = $codeApplicable; exists = (Test-ProjectDirectory 'Code文档'); reason = 'project contains recognized code indicators' }
)
$missingCoreDirectories = @($coreDirectoryChecks | Where-Object { $_.applies -and -not $_.exists } | ForEach-Object { $_.path })

$domainReferencePaths = @('领域参考资料', '硬件参考')
$presentDomainReferencePaths = @($domainReferencePaths | Where-Object { Test-ProjectDirectory $_ })
$conditionalDirectoryChecks = @(
    [ordered]@{ path = '规划文档\Spec文档'; exists = (Test-ProjectDirectory '规划文档\Spec文档'); condition = 'a formal PRD or Spec is commissioned' },
    [ordered]@{ path = '规划文档\里程碑文档'; exists = (Test-ProjectDirectory '规划文档\里程碑文档'); condition = 'delivery has named stages or stage acceptance' },
    [ordered]@{ path = '规划文档\产品迭代'; exists = (Test-ProjectDirectory '规划文档\产品迭代'); condition = 'product behavior is managed across versions' },
    [ordered]@{ path = '规划文档\技术验证'; exists = (Test-ProjectDirectory '规划文档\技术验证'); condition = 'research, PoC, feasibility, or technical preflight is required' },
    [ordered]@{ path = 'UI美术文档'; exists = (Test-ProjectDirectory 'UI美术文档'); condition = 'UI, visual, asset, or design acceptance work exists' },
    [ordered]@{ path = '协同工作文档\Hermes_handoff'; exists = (Test-ProjectDirectory '协同工作文档\Hermes_handoff'); condition = 'first critical-document Hermes review starts' },
    [ordered]@{ path = '协同工作文档\文档QA'; exists = (Test-ProjectDirectory '协同工作文档\文档QA'); condition = 'a serious document finding enters QA remediation' },
    [ordered]@{ path = '协同工作文档\交流记录'; exists = (Test-ProjectDirectory '协同工作文档\交流记录'); condition = 'decision-bearing communication must persist' },
    [ordered]@{ path = '协同工作文档\通知与对齐'; exists = (Test-ProjectDirectory '协同工作文档\通知与对齐'); condition = 'formal notice or alignment evidence is required' },
    [ordered]@{ path = '协同工作文档\会话存档'; exists = (Test-ProjectDirectory '协同工作文档\会话存档'); condition = 'a session export is required for continuity' },
    [ordered]@{ path = '协同工作文档\清单与裁决'; exists = (Test-ProjectDirectory '协同工作文档\清单与裁决'); condition = 'a separate checklist or formal ruling is required' },
    [ordered]@{ path = '协同工作文档\审查报告'; exists = (Test-ProjectDirectory '协同工作文档\审查报告'); condition = 'review evidence needs a dedicated area' },
    [ordered]@{ path = '协同工作文档\验收与澄清'; exists = (Test-ProjectDirectory '协同工作文档\验收与澄清'); condition = 'acceptance has conditions or residual-risk clarification' },
    [ordered]@{ path = '协同工作文档\完成报告'; exists = (Test-ProjectDirectory '协同工作文档\完成报告'); condition = 'a stage passed its applicable acceptance gates' },
    [ordered]@{ path = 'Code文档\技术笔记'; exists = (Test-ProjectDirectory 'Code文档\技术笔记'); condition = 'code-local technical notes are required' },
    [ordered]@{ path = 'Code文档\环境验证'; exists = (Test-ProjectDirectory 'Code文档\环境验证'); condition = 'environment setup or compatibility needs evidence' },
    [ordered]@{ path = 'Code文档\自测报告'; exists = (Test-ProjectDirectory 'Code文档\自测报告'); condition = 'producer self-test evidence is required' },
    [ordered]@{ path = 'Code文档\scripts'; exists = (Test-ProjectDirectory 'Code文档\scripts'); condition = 'project-owned automation scripts exist' },
    [ordered]@{ path = 'Code文档\tests'; exists = (Test-ProjectDirectory 'Code文档\tests'); condition = 'executable project verification exists' },
    [ordered]@{ path = 'Code文档\docs'; exists = (Test-ProjectDirectory 'Code文档\docs'); condition = 'documentation is owned with code' },
    [ordered]@{ path = '领域参考资料'; exists = $presentDomainReferencePaths.Count -gt 0; accepted_paths = $presentDomainReferencePaths; condition = 'hardware or specialist reference material exists' }
)

$warnings = @($scanDiagnostics)
if (@($entryDocs | Where-Object { [IO.Path]::GetFileName($_) -eq 'AGENTS.md' }).Count -eq 0) {
    $warnings += 'No AGENTS.md found in scanned files; confirm instructions manually.'
}
if ($gitMarkerExists -and -not $isGit) {
    $warnings += '.git exists but git rev-parse failed; treat this directory as a non-repository until repaired.'
}
if ($dirtyEntries.Count -gt 0) {
    $warnings += 'Git worktree has existing changes in the scanned scope; preserve unrelated user work.'
}
foreach ($missingDirectory in $missingCoreDirectories) {
    $warnings += "Applicable project structure directory missing: $missingDirectory. Report only; do not create, move, or delete without authorization."
}

$structureStatus = if (-not $scanComplete) {
    'STRUCTURE_SCAN_INCOMPLETE'
} elseif ($missingCoreDirectories.Count -eq 0) {
    'CONFORMANT_AT_CORE_LEVEL'
} else {
    'STRUCTURE_REVIEW_REQUIRED'
}

$result = [ordered]@{
    root = $root
    scanned_at = (Get-Date).ToString('o')
    file_count = $allFiles.Count
    scan = [ordered]@{
        complete = $scanComplete
        engine = $scanEngine
        diagnostic_count = $scanDiagnostics.Count
        diagnostics = @($scanDiagnostics)
    }
    git = [ordered]@{
        marker_exists = $gitMarkerExists
        is_repository = $isGit
        repository_root = $gitRoot
        scanned_scope_is_repository_root = $isGit -and ([string]$gitRoot).Equals($root, [StringComparison]::OrdinalIgnoreCase)
        branch = $branch
        dirty_entry_count = $dirtyEntries.Count
        dirty_entries = $dirtyEntries
    }
    top_level = $topLevel
    repository_structure = [ordered]@{
        precedence = 'Codex primary; WorkBuddy supplemental only where non-conflicting'
        mutation_authorized = $false
        status = $structureStatus
        core = $coreDirectoryChecks
        missing_applicable_core = $missingCoreDirectories
        conditional = $conditionalDirectoryChecks
    }
    entry_docs = $entryDocs
    source_of_truth_candidates = $sourceDocs
    manifests = $manifests
    code_indicators = [ordered]@{
        applicable = $codeApplicable
        source_file_count = $codeIndicators.Count
        recognized_extensions = $codeExtensions
    }
    issues = [ordered]@{
        open_file_count = $openIssues.Count
        closed_file_count = $closedIssues.Count
        canonical_tables = $issueTables
        open_files = $openIssues
    }
    thread_registry = [ordered]@{
        files = $threadRegistryFiles
        id_candidates = $threadIdCandidates
        live_validation_required = $true
    }
    verification_scripts = $verificationScripts
    warnings = $warnings
}

if ($Format -eq 'Json') {
    $result | ConvertTo-Json -Depth 9
    exit 0
}

Write-Output "Root: $root"
Write-Output "Files scanned: $($allFiles.Count)"
Write-Output "Scan complete: $scanComplete (engine=$scanEngine)"
Write-Output "Git repository: $isGit"
if ($isGit) {
    Write-Output "Repository root: $gitRoot"
    Write-Output "Branch: $branch"
    Write-Output "Dirty entries in scanned scope: $($dirtyEntries.Count)"
}
Write-Output "Open Issue files: $($openIssues.Count)"
Write-Output "Closed Issue files: $($closedIssues.Count)"

Write-Output "`nRepository structure: $($result.repository_structure.status)"
Write-Output "  Precedence: $($result.repository_structure.precedence)"
foreach ($item in $coreDirectoryChecks) {
    Write-Output "  core path=$($item.path) applies=$($item.applies) exists=$($item.exists)"
}
foreach ($item in $conditionalDirectoryChecks) {
    Write-Output "  conditional path=$($item.path) exists=$($item.exists) condition=$($item.condition)"
}

Write-Output "`nThread registry candidates:"
if ($threadRegistryFiles.Count -eq 0) { Write-Output '  (none)' }
foreach ($item in ($threadIdCandidates | Select-Object -First 30)) {
    Write-Output "  $($item.file)"
    foreach ($id in $item.ids) { Write-Output "    $id" }
}
if ($threadRegistryFiles.Count -gt 0) {
    Write-Output '  Live Codex thread validation is required before dispatch.'
}

Write-Output "`nCanonical Issue tables:"
if ($issueTables.Count -eq 0) { Write-Output '  (none)' }
foreach ($file in ($issueTables | Select-Object -First 20)) { Write-Output "  $file" }

Write-Output "`nEntry docs:"
if ($entryDocs.Count -eq 0) { Write-Output '  (none)' }
foreach ($file in ($entryDocs | Select-Object -First 20)) { Write-Output "  $file" }

Write-Output "`nSource-of-truth candidates:"
if ($sourceDocs.Count -eq 0) { Write-Output '  (none)' }
foreach ($file in ($sourceDocs | Select-Object -First 20)) { Write-Output "  $file" }

Write-Output "`nManifests:"
if ($manifests.Count -eq 0) { Write-Output '  (none)' }
foreach ($file in ($manifests | Select-Object -First 20)) { Write-Output "  $file" }

Write-Output "`nVerification scripts:"
if ($verificationScripts.Count -eq 0) { Write-Output '  (none detected)' }
foreach ($manifest in $verificationScripts.Keys) {
    Write-Output "  $manifest"
    foreach ($name in $verificationScripts[$manifest].Keys) {
        Write-Output "    $name = $($verificationScripts[$manifest][$name])"
    }
}

if ($warnings.Count -gt 0) {
    Write-Output "`nWarnings:"
    foreach ($warning in $warnings) { Write-Output "  $warning" }
}

exit 0
