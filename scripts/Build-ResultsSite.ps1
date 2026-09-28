[CmdletBinding()]
param(
    [string]$RunsPath = (Join-Path $PSScriptRoot '..\runs'),
    [string]$SitePath = (Join-Path $PSScriptRoot '..\site'),
    [long]$MaxFileBytes = 5MB,
    [ValidateSet('Local', 'Public')]
    [string]$Profile = 'Local'
)

$ErrorActionPreference = 'Stop'

$runsRoot = [IO.Path]::GetFullPath($RunsPath)
$siteRoot = [IO.Path]::GetFullPath($SitePath)
$dataRoot = Join-Path $siteRoot 'data'
$publishedRunsRoot = Join-Path $dataRoot 'runs'

if (-not (Test-Path -LiteralPath $runsRoot -PathType Container)) {
    throw "Runs-mappen saknas: $runsRoot"
}

New-Item -ItemType Directory -Force -Path $dataRoot | Out-Null

if (Test-Path -LiteralPath $publishedRunsRoot) {
    $resolvedOutput = (Resolve-Path -LiteralPath $publishedRunsRoot).Path
    $requiredPrefix = $siteRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedOutput.StartsWith($requiredPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Vägrar rensa en mapp utanför site: $resolvedOutput"
    }
    Remove-Item -LiteralPath $resolvedOutput -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $publishedRunsRoot | Out-Null

$allowedExtensions = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
@('.cs', '.razor', '.cshtml', '.csproj', '.sln', '.slnx', '.json', '.jsonl', '.md', '.txt', '.log', '.xml', '.props', '.targets', '.css', '.js', '.html', '.yml', '.yaml', '.config', '.http', '.ps1', '.trx', '.patch') |
    ForEach-Object { [void]$allowedExtensions.Add($_) }
$allowedNames = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
@('.editorconfig', '.gitignore') | ForEach-Object { [void]$allowedNames.Add($_) }
$excludedSegments = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
@('bin', 'obj', '.git', '.vs', 'node_modules') | ForEach-Object { [void]$excludedSegments.Add($_) }

function Read-JsonFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-OptionalProperty($Object, [string]$Name) {
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Select-FirstValue($Primary, $Fallback) {
    if ($null -ne $Primary) { return $Primary }
    return $Fallback
}

function New-ResultItem([string]$Key, [string]$Label, [string]$Status, $Value, [string]$Note = $null, [string]$ArtifactPath = $null) {
    return [ordered]@{
        key = $Key
        label = $Label
        status = $Status
        value = if ($null -eq $Value -or $Value -eq '') { 'Ej registrerat' } else { [string]$Value }
        note = $Note
        artifactPath = $ArtifactPath
    }
}

function Test-PublicArtifact([string]$RelativePath) {
    if ($RelativePath -in @('manifest.json', 'README.md')) { return $true }
    if ($RelativePath -match '^(implementation|buggfix)/(prompt\.md|input-files\.json|run\.json|final-response\.md|changes\.patch|assessment\.json)$') { return $true }
    if ($RelativePath -match '^(implementation|buggfix)/test-results/summary\.json$') { return $true }
    if ($RelativePath -match '^implementation/workspace/') { return $true }
    if ($RelativePath -match '^buggfix/(input|workspace)/') { return $true }
    return $false
}

function Copy-PublicTextFile([string]$Source, [string]$Destination, [string]$RepositoryRoot) {
    $content = Get-Content -LiteralPath $Source -Raw -Encoding UTF8
    if ($null -eq $content) { $content = '' }
    $content = [Regex]::Replace($content, [Regex]::Escape($RepositoryRoot), '[workspace]', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $forwardRoot = $RepositoryRoot.Replace('\', '/')
    $content = [Regex]::Replace($content, [Regex]::Escape($forwardRoot), '[workspace]', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $content = [Regex]::Replace($content, '(?i)\b[A-Z]:\\Users\\[^\\/\r\n"'']+', '[user-profile]')
    $content = [Regex]::Replace($content, '(?i)(/Users|/home)/[^/\s"'']+', '[user-profile]')
    Set-Content -LiteralPath $Destination -Value $content -Encoding UTF8 -NoNewline
}

$publishedRuns = [Collections.Generic.List[object]]::new()
$repositoryRoot = [IO.Path]::GetFullPath((Split-Path -Parent $runsRoot))
$runDirectories = Get-ChildItem -LiteralPath $runsRoot -Directory | Where-Object {
    $parsed = [Guid]::Empty
    [Guid]::TryParse($_.Name, [ref]$parsed)
}

foreach ($runDirectory in $runDirectories) {
    $manifestPath = Join-Path $runDirectory.FullName 'manifest.json'
    $manifest = Read-JsonFile $manifestPath
    if ($null -eq $manifest) { continue }

    $targetRoot = Join-Path $publishedRunsRoot $runDirectory.Name
    New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null
    $files = [Collections.Generic.List[object]]::new()
    $workspaceFileCount = 0
    $workspaceAddedLines = 0

    foreach ($file in Get-ChildItem -LiteralPath $runDirectory.FullName -Recurse -File) {
        $relativePath = [IO.Path]::GetRelativePath($runDirectory.FullName, $file.FullName).Replace('\', '/')
        $segments = $relativePath.Split('/')
        if ($segments | Where-Object { $excludedSegments.Contains($_) }) { continue }
        if ($file.Length -gt $MaxFileBytes) { continue }
        if (-not ($allowedExtensions.Contains($file.Extension) -or $allowedNames.Contains($file.Name))) { continue }
        if ($Profile -eq 'Public' -and -not (Test-PublicArtifact $relativePath)) { continue }

        $targetPath = Join-Path $targetRoot ($relativePath.Replace('/', [IO.Path]::DirectorySeparatorChar))
        $targetDirectory = Split-Path -Parent $targetPath
        New-Item -ItemType Directory -Force -Path $targetDirectory | Out-Null
        if ($Profile -eq 'Public') {
            Copy-PublicTextFile -Source $file.FullName -Destination $targetPath -RepositoryRoot $repositoryRoot
        }
        else {
            Copy-Item -LiteralPath $file.FullName -Destination $targetPath
        }

        $files.Add([ordered]@{
            path = $relativePath
            url = "data/runs/$($runDirectory.Name)/$relativePath"
            sizeBytes = $file.Length
        })

        if ($relativePath.StartsWith('implementation/workspace/', [StringComparison]::OrdinalIgnoreCase) -and
            -not $relativePath.EndsWith('/REQUIREMENTS.md', [StringComparison]::OrdinalIgnoreCase)) {
            $workspaceFileCount++
            $workspaceAddedLines += @(Get-Content -LiteralPath $file.FullName -Encoding UTF8 -ErrorAction SilentlyContinue).Count
        }
    }

    $implementationRun = Read-JsonFile (Join-Path $runDirectory.FullName 'implementation\run.json')
    $testSummary = Read-JsonFile (Join-Path $runDirectory.FullName 'implementation\test-results\summary.json')
    $assessment = Read-JsonFile (Join-Path $runDirectory.FullName 'implementation\assessment.json')
    $testCounters = $null
    $trxFile = Get-ChildItem -LiteralPath (Join-Path $runDirectory.FullName 'implementation\test-results') -Filter '*.trx' -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $trxFile) {
        [xml]$trx = Get-Content -LiteralPath $trxFile.FullName -Raw -Encoding UTF8
        $testCounters = $trx.TestRun.ResultSummary.Counters
    }
    $implementationManifest = Get-OptionalProperty (Get-OptionalProperty $manifest 'phases') 'implementation'

    $eventStats = [ordered]@{
        turns = 0
        agentMessages = 0
        commandExecutions = 0
        fileChanges = 0
        modelBuildAttempts = 0
        modelTestAttempts = 0
    }
    $eventsPath = Join-Path $runDirectory.FullName 'implementation\events.jsonl'
    if (Test-Path -LiteralPath $eventsPath -PathType Leaf) {
        foreach ($eventLine in Get-Content -LiteralPath $eventsPath -Encoding UTF8) {
            try { $event = $eventLine | ConvertFrom-Json -ErrorAction Stop } catch { continue }
            if ($event.type -eq 'turn.started') { $eventStats.turns++ }
            if ($event.type -ne 'item.completed') { continue }
            $itemType = Get-OptionalProperty $event.item 'type'
            switch ($itemType) {
                'agent_message' { $eventStats.agentMessages++ }
                'file_change' { $eventStats.fileChanges++ }
                'command_execution' {
                    $eventStats.commandExecutions++
                    $command = [string](Get-OptionalProperty $event.item 'command')
                    if ($command -match '(?i)\bdotnet\s+build\b') { $eventStats.modelBuildAttempts++ }
                    if ($command -match '(?i)\bdotnet\s+test\b') { $eventStats.modelTestAttempts++ }
                }
            }
        }
    }

    $implementation = [ordered]@{
        status = Get-OptionalProperty $implementationRun 'status'
        model = Select-FirstValue (Get-OptionalProperty $implementationRun 'model') (Get-OptionalProperty $implementationManifest 'model')
        reasoningEffort = Select-FirstValue (Get-OptionalProperty $implementationRun 'reasoningEffort') (Get-OptionalProperty $implementationManifest 'reasoningEffort')
        promptVersion = Select-FirstValue (Get-OptionalProperty $implementationRun 'promptVersion') (Get-OptionalProperty $implementationManifest 'promptVersion')
        startedAtUtc = Get-OptionalProperty $implementationRun 'startedAtUtc'
        completedAtUtc = Get-OptionalProperty $implementationRun 'completedAtUtc'
        durationSeconds = Get-OptionalProperty $implementationRun 'durationSeconds'
        maxDurationMinutes = Get-OptionalProperty $implementationRun 'maxDurationMinutes'
        timedOut = Get-OptionalProperty $implementationRun 'timedOut'
        inputTokens = Get-OptionalProperty $implementationRun 'inputTokens'
        outputTokens = Get-OptionalProperty $implementationRun 'outputTokens'
        reasoningTokens = Get-OptionalProperty $implementationRun 'reasoningTokens'
        cachedInputTokens = Get-OptionalProperty $implementationRun 'cachedInputTokens'
        exitCode = Get-OptionalProperty $implementationRun 'exitCode'
        buildExitCode = Get-OptionalProperty $implementationRun 'buildExitCode'
        testExitCode = Get-OptionalProperty $implementationRun 'testExitCode'
        verificationPassed = Get-OptionalProperty $implementationRun 'verificationPassed'
        codexVersion = Get-OptionalProperty $implementationRun 'codexVersion'
        dotnetVersion = Get-OptionalProperty $implementationRun 'dotnetVersion'
        testsPassed = Select-FirstValue (Get-OptionalProperty $testSummary 'passed') (Get-OptionalProperty $testCounters 'passed')
        testsTotal = Select-FirstValue (Get-OptionalProperty $testSummary 'total') (Get-OptionalProperty $testCounters 'total')
    }

    $resultItems = [Collections.Generic.List[object]]::new()
    $modeValue = "implementation / $($implementation.promptVersion)"
    $resultItems.Add((New-ResultItem 'mode' 'Benchmarkläge och variant' 'available' $modeValue))
    $startCommit = Get-OptionalProperty $implementationManifest 'referenceCommit'
    $resultItems.Add((New-ResultItem 'startCommit' 'Start-commit' $(if ($startCommit) { 'available' } else { 'missing' }) $startCommit 'Git användes inte för dessa körningar.'))
    $modelValue = if ($implementation.model) { "$($implementation.model); Codex $($implementation.codexVersion)" } else { $null }
    $resultItems.Add((New-ResultItem 'model' 'Modell och exakt modellversion' $(if ($implementation.model) { 'available' } else { 'missing' }) $modelValue))
    $dateValue = if ($implementation.startedAtUtc) { "$($implementation.startedAtUtc) – $($implementation.completedAtUtc)" } else { $null }
    $resultItems.Add((New-ResultItem 'dateTime' 'Datum och tid' $(if ($dateValue) { 'available' } else { 'missing' }) $dateValue))
    $hasPrompt = Test-Path -LiteralPath (Join-Path $runDirectory.FullName 'implementation\prompt.md')
    $resultItems.Add((New-ResultItem 'instructions' 'Systeminstruktion och uppgiftsprompt' $(if ($hasPrompt) { 'partial' } else { 'missing' }) $(if ($hasPrompt) { 'Uppgiftsprompten är sparad; systeminstruktionen är inte separat registrerad.' } else { $null }) $null $(if ($hasPrompt) { 'implementation/prompt.md' } else { $null })))
    $toolsValue = if ($implementationRun) { "Codex CLI; isolering: $(Get-OptionalProperty $implementationRun 'codexHomeIsolation'); inaktiverat: $((Get-OptionalProperty $implementationRun 'disabledFeatures') -join ', ')" } else { $null }
    $resultItems.Add((New-ResultItem 'tools' 'Tillåtna verktyg' $(if ($toolsValue) { 'partial' } else { 'missing' }) $toolsValue 'Exakt verktygslista registrerades inte strukturerat.' 'implementation/command.txt'))
    $maxDurationValue = if ($null -ne $implementation.maxDurationMinutes) { "$($implementation.maxDurationMinutes) minuter" } else { $null }
    $maxDurationNote = if ($implementation.timedOut -eq $true) {
        'Körningen stoppades när tidsgränsen nåddes.'
    }
    elseif ($null -ne $implementation.maxDurationMinutes) {
        'Tidsgränsen verkställs av körskriptet för Codex-processen.'
    }
    else {
        'Ingen verkställd tidsgräns registrerades för denna historiska körning.'
    }
    $resultItems.Add((New-ResultItem 'maxDuration' 'Maximal körtid' $(if ($maxDurationValue) { 'available' } else { 'missing' }) $maxDurationValue $maxDurationNote))
    $interactionValue = if (Test-Path -LiteralPath $eventsPath) { "$($eventStats.turns) modellturn; $($eventStats.agentMessages) agentmeddelanden; $($eventStats.commandExecutions) kommandon; $($eventStats.fileChanges) filändringar" } else { $null }
    $resultItems.Add((New-ResultItem 'interactions' 'Antal modellinteraktioner' $(if ($interactionValue) { 'available' } else { 'missing' }) $interactionValue $null 'implementation/events.jsonl'))
    $tokenValue = if ($null -ne $implementation.inputTokens) { "$($implementation.inputTokens) input; $($implementation.cachedInputTokens) cachade; $($implementation.outputTokens) output" } else { $null }
    $resultItems.Add((New-ResultItem 'tokens' 'In- och utgående tokens' $(if ($tokenValue) { 'available' } else { 'missing' }) $tokenValue))
    $resultItems.Add((New-ResultItem 'cost' 'Uppskattad kostnad' 'missing' $null 'Ingen prislista eller kostnadsberäkning sparades vid körningen.'))
    $resultItems.Add((New-ResultItem 'duration' 'Total körtid' $(if ($null -ne $implementation.durationSeconds) { 'available' } else { 'missing' }) $(if ($null -ne $implementation.durationSeconds) { "$($implementation.durationSeconds) sekunder" } else { $null })))
    $harnessBuildAttempts = if ($null -ne $implementation.buildExitCode) { 1 } else { 0 }
    $harnessTestAttempts = if ($null -ne $implementation.testExitCode) { 1 } else { 0 }
    $attemptValue = if (Test-Path -LiteralPath $eventsPath) { "Modellen: $($eventStats.modelBuildAttempts) build och $($eventStats.modelTestAttempts) test; styrskriptet: $harnessBuildAttempts build och $harnessTestAttempts test" } else { $null }
    $resultItems.Add((New-ResultItem 'attempts' 'Antal bygg- och testförsök' $(if ($attemptValue) { 'available' } else { 'missing' }) $attemptValue))
    $resultItems.Add((New-ResultItem 'changedFiles' 'Antal ändrade filer' 'available' $workspaceFileCount 'Implementation från tom arbetsyta; REQUIREMENTS.md räknas inte.'))
    $hasPatch = Test-Path -LiteralPath (Join-Path $runDirectory.FullName 'implementation\changes.patch')
    $addedLines = Select-FirstValue (Get-OptionalProperty $implementationRun 'addedLines') $workspaceAddedLines
    $deletedLines = Select-FirstValue (Get-OptionalProperty $implementationRun 'deletedLines') 0
    $resultItems.Add((New-ResultItem 'changedLines' 'Tillagda och borttagna kodrader' $(if ($hasPatch) { 'available' } else { 'partial' }) "+$addedLines / -$deletedLines" $(if ($hasPatch) { 'Beräknat när changes.patch skapades.' } else { 'Historiskt värde beräknat från arbetsytans textfiler.' }) $(if ($hasPatch) { 'implementation/changes.patch' } else { $null })))
    $buildValue = if ($null -ne $implementation.buildExitCode) { if ($implementation.buildExitCode -eq 0) { 'Godkänd (exit 0)' } else { "Misslyckad (exit $($implementation.buildExitCode))" } } else { $null }
    $resultItems.Add((New-ResultItem 'build' 'Byggresultat' $(if ($buildValue) { 'available' } else { 'missing' }) $buildValue $null 'implementation/test-results/build.log'))
    $categoryValues = [Collections.Generic.List[string]]::new()
    if ($testSummary -and (Get-OptionalProperty $testSummary 'categories')) {
        foreach ($property in $testSummary.categories.PSObject.Properties) {
            $category = $property.Value
            $categoryValues.Add("$($category.name): $($category.passed)/$($category.total)")
        }
    }
    $testValue = if ($categoryValues.Count -gt 0) { $categoryValues -join '; ' } elseif ($null -ne $implementation.testsTotal) { "Automatiska .NET-tester: $($implementation.testsPassed)/$($implementation.testsTotal) godkända" } else { $null }
    $resultItems.Add((New-ResultItem 'testCategories' 'Resultat per testkategori' $(if ($categoryValues.Count -gt 0) { 'available' } elseif ($testValue) { 'partial' } else { 'missing' }) $testValue $(if ($categoryValues.Count -gt 0) { 'Kategoriserat från TRX-testnamn.' } else { 'Historiska testresultat saknar kategorisering.' }) $(if ($testSummary) { 'implementation/test-results/summary.json' } else { $null })))
    $resultItems.Add((New-ResultItem 'fixedBugs' 'Lösta buggrapporter' 'not_applicable' 'Inte tillämpligt i implementationsläget'))
    $resultItems.Add((New-ResultItem 'regressions' 'Antal regressioner' 'missing' $null 'Ingen separat regressionssvit eller baslinjejämförelse kördes.'))
    $partialScoreValue = if ($assessment) { "Blazor $($assessment.partialScores.blazor.score)/$($assessment.partialScores.blazor.maxScore); API $($assessment.partialScores.api.score)/$($assessment.partialScores.api.maxScore); affärslogik $($assessment.partialScores.businessLogic.score)/$($assessment.partialScores.businessLogic.maxScore)" } else { $null }
    $resultItems.Add((New-ResultItem 'partialScores' 'Delpoäng: Blazor, API och affärslogik' $(if ($assessment) { 'partial' } else { 'missing' }) $partialScoreValue $(if ($assessment) { $assessment.note } else { 'Historisk körning utan assessment.json.' }) $(if ($assessment) { 'implementation/assessment.json' } else { $null })))
    $finalScoreValue = if ($assessment) { "$($assessment.score)/$($assessment.maxScore) poäng; verifierat underlag $($assessment.evaluatedMaxScore)/$($assessment.maxScore)" } else { $null }
    $resultItems.Add((New-ResultItem 'finalScore' 'Slutpoäng' $(if ($assessment) { 'partial' } else { 'missing' }) $finalScoreValue $(if ($assessment) { 'Preliminär automatiserad poäng; dolda benchmarktester krävs för slutgiltig poäng.' } else { 'Historisk körning utan assessment.json.' }) $(if ($assessment) { 'implementation/assessment.json' } else { $null })))
    $workspaceHash = Get-OptionalProperty $implementationRun 'workspaceContentSha256'
    $resultItems.Add((New-ResultItem 'finalChange' 'Modellens slutliga kodändring' $(if ($hasPatch) { 'available' } elseif ($workspaceHash) { 'partial' } else { 'missing' }) $(if ($workspaceHash) { "Arbetsytans SHA-256: $workspaceHash" } else { $null }) $(if ($hasPatch) { 'Fullständig patch från den tomma implementationsbaslinjen.' } else { 'Historisk körning där changes.patch saknas.' }) $(if ($hasPatch) { 'implementation/changes.patch' } else { $null })))
    $hasFinalResponse = Test-Path -LiteralPath (Join-Path $runDirectory.FullName 'implementation\final-response.md')
    $resultItems.Add((New-ResultItem 'summary' 'Modellens sammanfattning' $(if ($hasFinalResponse) { 'available' } else { 'missing' }) $(if ($hasFinalResponse) { 'Sparad i final-response.md' } else { $null }) $null $(if ($hasFinalResponse) { 'implementation/final-response.md' } else { $null })))

    $publishedRuns.Add([ordered]@{
        id = $runDirectory.Name
        createdAtUtc = Get-OptionalProperty $manifest 'createdAtUtc'
        description = Get-OptionalProperty $manifest 'description'
        status = Get-OptionalProperty $manifest 'status'
        manifestUrl = "data/runs/$($runDirectory.Name)/manifest.json"
        implementation = $implementation
        resultItems = @($resultItems)
        files = @($files | Sort-Object path)
    })
}

$index = [ordered]@{
    schemaVersion = 1
    generatedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    publicationProfile = $Profile.ToLowerInvariant()
    runs = @($publishedRuns | Sort-Object @{ Expression = { $_.createdAtUtc }; Descending = $true }, @{ Expression = { $_.id }; Descending = $false })
}

$indexPath = Join-Path $dataRoot 'runs.json'
$index | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $indexPath -Encoding UTF8

if ($Profile -eq 'Public') {
    $publication = [ordered]@{
        schemaVersion = 1
        profile = 'public'
        generatedAtUtc = $index.generatedAtUtc
        included = @('manifest och run-metadata', 'prompter', 'slutsvar', 'publicerbar källkod')
        excluded = @('events.jsonl', 'command.txt', 'stderr.log', 'bygg- och testloggar', 'TRX-filer', 'buggfix/preparation och privata facit')
        sanitization = @('arbetsytesökvägar', 'användarprofilssökvägar')
    }
    $publication | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $dataRoot 'publication.json') -Encoding UTF8

    $sensitivePatterns = [ordered]@{
        'absolut Windows-sökväg' = '(?i)\b[A-Z]:[\\/]'
        'absolut användarsökväg' = '(?i)(/Users|/home)/[^/\s"'']+'
        'intern Azure Artifacts-feed' = '(?i)https?://[^\s"'']*pkgs\.visualstudio\.com'
        'Bearer-token' = '(?i)Bearer\s+[A-Za-z0-9._-]{20,}'
        'API-nyckel' = '(?i)(api[_-]?key|access[_-]?token|client[_-]?secret)\s*[:=]\s*["'']?[A-Za-z0-9._-]{12,}'
        'OpenAI-liknande token' = 'sk-[A-Za-z0-9_-]{20,}'
    }
    $findings = [Collections.Generic.List[string]]::new()
    foreach ($publishedFile in Get-ChildItem -LiteralPath $dataRoot -Recurse -File) {
        $content = Get-Content -LiteralPath $publishedFile.FullName -Raw -Encoding UTF8
        foreach ($entry in $sensitivePatterns.GetEnumerator()) {
            if ($content -match $entry.Value) {
                $relativePublishedPath = [IO.Path]::GetRelativePath($siteRoot, $publishedFile.FullName)
                $findings.Add("$($entry.Key): $relativePublishedPath")
            }
        }
    }
    if ($findings.Count -gt 0) {
        throw "Den offentliga exporten stoppades eftersom potentiellt känsligt innehåll hittades:`n$($findings -join "`n")"
    }
}

Write-Host "Publicerade $($publishedRuns.Count) körningar med profilen $Profile till $indexPath"
