[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\dist')
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$outputRoot = [IO.Path]::GetFullPath($OutputPath)
$requiredPrefix = $repositoryRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar

if (-not $outputRoot.StartsWith($requiredPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Den offentliga exporten måste ligga under arbetsytan: $repositoryRoot"
}
if ($outputRoot -in @($repositoryRoot, (Join-Path $repositoryRoot 'site'), (Join-Path $repositoryRoot 'runs'))) {
    throw "Ogiltig exportmapp: $outputRoot"
}

if (Test-Path -LiteralPath $outputRoot) {
    $resolvedOutput = (Resolve-Path -LiteralPath $outputRoot).Path
    if (-not $resolvedOutput.StartsWith($requiredPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Vägrar rensa en mapp utanför arbetsytan: $resolvedOutput"
    }
    Remove-Item -LiteralPath $resolvedOutput -Recurse -Force
}

New-Item -ItemType Directory -Path $outputRoot | Out-Null
$siteRoot = Join-Path $repositoryRoot 'site'
foreach ($asset in @('index.html', 'styles.css', 'app.js')) {
    Copy-Item -LiteralPath (Join-Path $siteRoot $asset) -Destination (Join-Path $outputRoot $asset)
}

& (Join-Path $PSScriptRoot 'Build-ResultsSite.ps1') -SitePath $outputRoot -Profile Public
Write-Host "Offentlig webbplats skapad i $outputRoot"
