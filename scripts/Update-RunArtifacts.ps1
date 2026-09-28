[CmdletBinding()]
param(
    [string] $RunsPath = (Join-Path $PSScriptRoot '..\runs')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'BenchmarkArtifacts.ps1')

function Write-JsonAtomically {
    param(
        [Parameter(Mandatory)] $Value,
        [Parameter(Mandatory)] [string] $Path,
        [int] $Depth = 20
    )

    $temporaryPath = "$Path.tmp"
    $Value | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $temporaryPath -Encoding utf8
    Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
}

$updated = 0
$runDirectories = Get-ChildItem -LiteralPath $RunsPath -Directory | Where-Object {
    $parsed = [Guid]::Empty
    [Guid]::TryParse($_.Name, [ref] $parsed)
}

foreach ($runDirectory in $runDirectories) {
    $phasePath = Join-Path $runDirectory.FullName 'implementation'
    $workspacePath = Join-Path $phasePath 'workspace'
    $runMetadataPath = Join-Path $phasePath 'run.json'
    $testResultsPath = Join-Path $phasePath 'test-results'
    if (-not (Test-Path -LiteralPath $workspacePath -PathType Container) -or
        -not (Test-Path -LiteralPath $runMetadataPath -PathType Leaf)) {
        continue
    }

    New-Item -ItemType Directory -Force -Path $testResultsPath | Out-Null
    $patchSummary = Write-ImplementationPatch -WorkspacePath $workspacePath -PatchPath (Join-Path $phasePath 'changes.patch')
    $testSummary = Get-BenchmarkTestSummary -TestResultsPath $testResultsPath
    Write-JsonAtomically -Value $testSummary -Path (Join-Path $testResultsPath 'summary.json')

    $runMetadata = Get-Content -LiteralPath $runMetadataPath -Raw -Encoding utf8 | ConvertFrom-Json
    $assessment = Get-ImplementationAssessment `
        -TestSummary $testSummary `
        -BuildExitCode $runMetadata.buildExitCode `
        -TestExitCode $runMetadata.testExitCode
    Write-JsonAtomically -Value $assessment -Path (Join-Path $phasePath 'assessment.json')

    $properties = [ordered]@{
        changesPatchPath = 'changes.patch'
        assessmentPath = 'assessment.json'
        changedFiles = $patchSummary.ChangedFiles
        addedLines = $patchSummary.AddedLines
        deletedLines = $patchSummary.DeletedLines
    }
    foreach ($entry in $properties.GetEnumerator()) {
        if ($runMetadata.PSObject.Properties.Name -contains $entry.Key) {
            $runMetadata.$($entry.Key) = $entry.Value
        }
        else {
            $runMetadata | Add-Member -NotePropertyName $entry.Key -NotePropertyValue $entry.Value
        }
    }
    Write-JsonAtomically -Value $runMetadata -Path $runMetadataPath
    $updated++
}

Write-Host "Uppdaterade artefakter för $updated implementationskörningar."
