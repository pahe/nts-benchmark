[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [Guid] $Id,

    [string] $Description = "RoomBooking från implementation till buggfix"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$runsRoot = Join-Path $repositoryRoot "runs"
$reservationsRoot = Join-Path $runsRoot ".reservations"
$runPath = Join-Path $runsRoot $Id.ToString()
$reservationPath = Join-Path $reservationsRoot ("{0}.lock" -f $Id)

New-Item -ItemType Directory -Force -Path $reservationsRoot | Out-Null

if (Test-Path -LiteralPath $runPath) {
    throw "Benchmarkomgången finns redan: $runPath"
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
    throw "Benchmarkomgången är redan reserverad: $Id"
}

$implementationPath = Join-Path $runPath "implementation"
$bugfixPath = Join-Path $runPath "buggfix"

@(
    $runPath,
    $implementationPath,
    (Join-Path $implementationPath "workspace"),
    (Join-Path $implementationPath "test-results"),
    $bugfixPath,
    (Join-Path $bugfixPath "preparation"),
    (Join-Path $bugfixPath "preparation\bugs"),
    (Join-Path $bugfixPath "input"),
    (Join-Path $bugfixPath "workspace"),
    (Join-Path $bugfixPath "test-results")
) | ForEach-Object {
    New-Item -ItemType Directory -Path $_ | Out-Null
}

$createdAt = [DateTimeOffset]::UtcNow.ToString("O")
$manifest = [ordered]@{
    schemaVersion = 1
    id = $Id.ToString()
    createdAtUtc = $createdAt
    description = $Description
    status = "implementation_pending"
    paths = [ordered]@{
        implementationWorkspace = "implementation/workspace"
        implementationPrompt = "implementation/prompt.md"
        implementationResults = "implementation/test-results"
        bugfixPreparation = "buggfix/preparation"
        bugfixInput = "buggfix/input"
        bugfixWorkspace = "buggfix/workspace"
        bugfixPrompt = "buggfix/prompt.md"
        bugfixResults = "buggfix/test-results"
    }
    phases = [ordered]@{
        implementation = [ordered]@{
            status = "pending"
            model = $null
            reasoningEffort = $null
            promptVersion = "implementation-v1"
            promptSha256 = $null
            referenceContentSha256 = $null
        }
        bugfix = [ordered]@{
            status = "blocked"
            model = $null
            reasoningEffort = $null
            promptVersion = "buggfix-v1"
            promptSha256 = $null
            inputContentSha256 = $null
        }
    }
}

$manifestPath = Join-Path $runPath "manifest.json"
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding utf8

$readme = @"
# Benchmarkomgång $Id

$Description

- [Implementation](implementation/workspace)
- [Implementationsprompt](implementation/prompt.md)
- [Implementationsresultat](implementation/test-results)
- [Felaktig buggfixindata](buggfix/input)
- [Buggfixarbetsyta](buggfix/workspace)
- [Buggfixprompt](buggfix/prompt.md)
- [Buggfixresultat](buggfix/test-results)
"@

$readme | Set-Content -LiteralPath (Join-Path $runPath "README.md") -Encoding utf8

Write-Output $Id.ToString()
