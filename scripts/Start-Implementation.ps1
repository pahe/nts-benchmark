[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [Guid] $Id,

    [string] $Model = "gpt-6-sol",

    [ValidateSet("none", "minimal", "low", "medium", "high", "xhigh", "max", "ultra")]
    [string] $ReasoningEffort = "medium",

    [string] $PromptPath,

    [string] $RequirementsPath,

    [ValidateRange(1, 1440)]
    [int] $TimeoutMinutes = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "BenchmarkProcess.ps1")
. (Join-Path $PSScriptRoot "BenchmarkArtifacts.ps1")

function Write-JsonAtomically {
    param(
        [Parameter(Mandatory)] $Value,
        [Parameter(Mandatory)] [string] $Path,
        [int] $Depth = 10
    )

    $temporaryPath = "$Path.tmp"
    $Value | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $temporaryPath -Encoding utf8
    Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
}

function Get-DirectoryContentHash {
    param([Parameter(Mandatory)] [string] $Path)

    $lines = Get-ChildItem -LiteralPath $Path -File -Recurse |
        Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' } |
        Sort-Object FullName |
        ForEach-Object {
            $relativePath = [System.IO.Path]::GetRelativePath($Path, $_.FullName).Replace("\", "/")
            $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
            "$relativePath`t$hash"
        }

    $joined = $lines -join "`n"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($joined)
    $digest = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return [Convert]::ToHexString($digest).ToLowerInvariant()
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
if (-not $PromptPath) {
    $PromptPath = Join-Path $repositoryRoot "prompts\implementation-v1.md"
}
if (-not $RequirementsPath) {
    $RequirementsPath = Join-Path $repositoryRoot "docs\room-booking-benchmark.md"
}

$runPath = Join-Path (Join-Path $repositoryRoot "runs") $Id.ToString()
$phasePath = Join-Path $runPath "implementation"
$workspacePath = Join-Path $phasePath "workspace"
$manifestPath = Join-Path $runPath "manifest.json"
$reservationPath = Join-Path (Join-Path $repositoryRoot "runs\.reservations") ("{0}.implementation.lock" -f $Id)

foreach ($requiredPath in @($runPath, $phasePath, $workspacePath, $manifestPath, $PromptPath, $RequirementsPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Obligatorisk sökväg saknas: $requiredPath"
    }
}

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
if ($manifest.phases.implementation.status -ne "pending") {
    throw "Implementationsfasen kan inte startas från status '$($manifest.phases.implementation.status)'."
}

if (Get-ChildItem -Force -LiteralPath $workspacePath | Select-Object -First 1) {
    throw "Implementationsarbetsytan är inte tom: $workspacePath"
}

try {
    $reservation = [System.IO.File]::Open(
        $reservationPath,
        [System.IO.FileMode]::CreateNew,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::None)
    $reservation.Dispose()
}
catch [System.IO.IOException] {
    throw "Implementationsfasen är redan reserverad för omgången $Id."
}

$savedPromptPath = Join-Path $phasePath "prompt.md"
$workspaceRequirementsPath = Join-Path $workspacePath "REQUIREMENTS.md"
Copy-Item -LiteralPath $PromptPath -Destination $savedPromptPath
Copy-Item -LiteralPath $RequirementsPath -Destination $workspaceRequirementsPath

$promptHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $savedPromptPath).Hash.ToLowerInvariant()
$requirementsHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $RequirementsPath).Hash.ToLowerInvariant()
$inputFiles = [ordered]@{
    schemaVersion = 1
    files = @(
        [ordered]@{
            role = "requirements"
            sourcePath = [System.IO.Path]::GetRelativePath($repositoryRoot, $RequirementsPath).Replace("\", "/")
            workspacePath = "REQUIREMENTS.md"
            sha256 = $requirementsHash
        }
    )
}
Write-JsonAtomically -Value $inputFiles -Path (Join-Path $phasePath "input-files.json")

$codexVersion = (& codex --version 2>$null | Select-Object -Last 1).Trim()
$dotnetVersion = (& dotnet --version).Trim()
$startedAt = [DateTimeOffset]::UtcNow
$finalResponsePath = Join-Path $phasePath "final-response.md"
$eventsPath = Join-Path $phasePath "events.jsonl"
$stderrPath = Join-Path $phasePath "stderr.log"
$configOverride = 'model_reasoning_effort="{0}"' -f $ReasoningEffort

$codexArguments = @(
    "--no-daemon",
    "exec",
    "--ignore-user-config",
    "--skip-git-repo-check",
    "--enable", "skip_host_skill_discovery",
    "--disable", "plugins",
    "--disable", "apps",
    "--disable", "multi_agent",
    "--model", $Model,
    "-c", $configOverride,
    "--json",
    "--output-last-message", $finalResponsePath,
    "--cd", $workspacePath,
    "--approve-for-me",
    "-"
)

$quotedArguments = $codexArguments | ForEach-Object {
    if ($_ -match '\s') { '"{0}"' -f ($_.Replace('"', '\"')) } else { $_ }
}
$commandText = "codex " + ($quotedArguments -join " ")
$commandText | Set-Content -LiteralPath (Join-Path $phasePath "command.txt") -Encoding utf8

$runMetadata = [ordered]@{
    schemaVersion = 1
    experimentId = $Id.ToString()
    phase = "implementation"
    status = "running"
    model = $Model
    reasoningEffort = $ReasoningEffort
    codexHomeIsolation = "temporary-auth-only"
    disabledFeatures = @("plugins", "apps", "multi_agent")
    promptPath = "prompt.md"
    promptVersion = "implementation-v1"
    promptSha256 = $promptHash
    inputFilesPath = "input-files.json"
    startedAtUtc = $startedAt.ToString("O")
    completedAtUtc = $null
    durationSeconds = $null
    maxDurationMinutes = $TimeoutMinutes
    timedOut = $false
    codexVersion = $codexVersion
    dotnetVersion = $dotnetVersion
    workspacePath = "workspace"
    exitCode = $null
    inputTokens = $null
    cachedInputTokens = $null
    outputTokens = $null
    reasoningTokens = $null
    buildExitCode = $null
    testExitCode = $null
    verificationPassed = $false
    workspaceContentSha256 = $null
    changesPatchPath = $null
    assessmentPath = $null
}
$runMetadataPath = Join-Path $phasePath "run.json"
Write-JsonAtomically -Value $runMetadata -Path $runMetadataPath

$manifest.status = "implementation_running"
$manifest.phases.implementation.status = "running"
$manifest.phases.implementation.model = $Model
$manifest.phases.implementation.reasoningEffort = $ReasoningEffort
$manifest.phases.implementation.promptSha256 = $promptHash
Write-JsonAtomically -Value $manifest -Path $manifestPath

$promptText = Get-Content -Raw -LiteralPath $savedPromptPath
$sourceCodexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }
$sourceAuthPath = Join-Path $sourceCodexHome "auth.json"
if (-not (Test-Path -LiteralPath $sourceAuthPath)) {
    throw "Codex-autentisering saknas: $sourceAuthPath"
}

$isolatedCodexHome = Join-Path ([System.IO.Path]::GetTempPath()) ("nts-benchmark-codex-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $isolatedCodexHome | Out-Null
Copy-Item -LiteralPath $sourceAuthPath -Destination (Join-Path $isolatedCodexHome "auth.json")
$codexExecutable = (Get-Command codex -ErrorAction Stop).Source

try {
    $codexResult = Invoke-BenchmarkProcess `
        -FilePath $codexExecutable `
        -ArgumentList $codexArguments `
        -WorkingDirectory $workspacePath `
        -StandardInput $promptText `
        -StandardOutputPath $eventsPath `
        -StandardErrorPath $stderrPath `
        -Environment @{ CODEX_HOME = $isolatedCodexHome } `
        -Timeout ([TimeSpan]::FromMinutes($TimeoutMinutes))
    $codexExitCode = $codexResult.ExitCode
    $runMetadata.timedOut = $codexResult.TimedOut
}
finally {
    $resolvedIsolatedHome = (Resolve-Path -LiteralPath $isolatedCodexHome).Path
    $temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd("\")
    if (-not $resolvedIsolatedHome.StartsWith($temporaryRoot + "\", [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Vägrar ta bort en isoleringskatalog utanför temp: $resolvedIsolatedHome"
    }
    Remove-Item -LiteralPath $resolvedIsolatedHome -Recurse -Force
}

$solution = Get-ChildItem -LiteralPath $workspacePath -Recurse -File |
    Where-Object { $_.Extension -in @(".sln", ".slnx") } |
    Sort-Object FullName |
    Select-Object -First 1

$buildExitCode = $null
$testExitCode = $null
$testResultsPath = Join-Path $phasePath "test-results"

if ($solution) {
    $buildOutput = & dotnet build $solution.FullName --nologo 2>&1
    $buildExitCode = $LASTEXITCODE
    $buildOutput | Set-Content -LiteralPath (Join-Path $testResultsPath "build.log") -Encoding utf8

    if ($buildExitCode -eq 0) {
        $testOutput = & dotnet test $solution.FullName --no-build --logger trx --results-directory $testResultsPath 2>&1
        $testExitCode = $LASTEXITCODE
        $testOutput | Set-Content -LiteralPath (Join-Path $testResultsPath "test.log") -Encoding utf8
    }
}
else {
    "Ingen .sln- eller .slnx-fil hittades." | Set-Content -LiteralPath (Join-Path $testResultsPath "build.log") -Encoding utf8
}

$patchPath = Join-Path $phasePath "changes.patch"
$patchSummary = Write-ImplementationPatch -WorkspacePath $workspacePath -PatchPath $patchPath
$testSummary = Get-BenchmarkTestSummary -TestResultsPath $testResultsPath
Write-JsonAtomically -Value $testSummary -Path (Join-Path $testResultsPath "summary.json")
$assessment = Get-ImplementationAssessment -TestSummary $testSummary -BuildExitCode $buildExitCode -TestExitCode $testExitCode
$assessmentPath = Join-Path $phasePath "assessment.json"
Write-JsonAtomically -Value $assessment -Path $assessmentPath

$usageEvent = Get-Content -LiteralPath $eventsPath -ErrorAction SilentlyContinue |
    ForEach-Object {
        try { $_ | ConvertFrom-Json } catch { $null }
    } |
    Where-Object { $_.type -eq "turn.completed" -and $_.usage } |
    Select-Object -Last 1

$completedAt = [DateTimeOffset]::UtcNow
$verificationPassed = $codexExitCode -eq 0 -and $solution -and $buildExitCode -eq 0 -and $testExitCode -eq 0
$workspaceHash = Get-DirectoryContentHash -Path $workspacePath

$runMetadata.status = if ($verificationPassed) { "completed" } else { "failed" }
$runMetadata.completedAtUtc = $completedAt.ToString("O")
$runMetadata.durationSeconds = [Math]::Round(($completedAt - $startedAt).TotalSeconds, 3)
$runMetadata.exitCode = $codexExitCode
$runMetadata.buildExitCode = $buildExitCode
$runMetadata.testExitCode = $testExitCode
$runMetadata.verificationPassed = $verificationPassed
$runMetadata.workspaceContentSha256 = $workspaceHash
$runMetadata.changesPatchPath = "changes.patch"
$runMetadata.assessmentPath = "assessment.json"
$runMetadata.changedFiles = $patchSummary.ChangedFiles
$runMetadata.addedLines = $patchSummary.AddedLines
$runMetadata.deletedLines = $patchSummary.DeletedLines

if ($usageEvent) {
    $runMetadata.inputTokens = $usageEvent.usage.input_tokens
    $runMetadata.cachedInputTokens = $usageEvent.usage.cached_input_tokens
    $runMetadata.outputTokens = $usageEvent.usage.output_tokens
    if ($usageEvent.usage.PSObject.Properties.Name -contains "reasoning_tokens") {
        $runMetadata.reasoningTokens = $usageEvent.usage.reasoning_tokens
    }
}

Write-JsonAtomically -Value $runMetadata -Path $runMetadataPath

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$manifest.status = if ($verificationPassed) { "implementation_completed" } else { "implementation_failed" }
$manifest.phases.implementation.status = if ($verificationPassed) { "completed" } else { "failed" }
$manifest.phases.implementation.referenceContentSha256 = $workspaceHash
Write-JsonAtomically -Value $manifest -Path $manifestPath

Write-Output ([pscustomobject]@{
    Id = $Id.ToString()
    Status = $runMetadata.status
    Workspace = $workspacePath
    CodexExitCode = $codexExitCode
    TimedOut = $runMetadata.timedOut
    BuildExitCode = $buildExitCode
    TestExitCode = $testExitCode
})
