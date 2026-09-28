[CmdletBinding()]
param([switch] $Check)

$projectPath = 'src/Nts.Benchmark.Cli/Nts.Benchmark.Cli.csproj'
$assetsPath = 'src/Nts.Benchmark.Cli/obj/project.assets.json'
if (-not (Test-Path -LiteralPath $assetsPath)) {
    & dotnet restore $projectPath --disable-parallel -p:RestoreIgnoreFailedSources=true -p:NuGetAudit=false
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$arguments = @('run', '--no-restore', '-p:NuGetAudit=false', '--project', $projectPath, '--')
if ($Check) { $arguments += '--check' }
& dotnet @arguments
exit $LASTEXITCODE
