function Test-BenchmarkExcludedPath {
    param([Parameter(Mandatory)] [string] $RelativePath)

    $normalized = $RelativePath.Replace('\', '/')
    if ($normalized -eq 'REQUIREMENTS.md') { return $true }
    return $normalized -match '(^|/)(bin|obj|\.git|\.vs|node_modules)(/|$)'
}

function Test-BenchmarkTextFile {
    param([Parameter(Mandatory)] [System.IO.FileInfo] $File)

    $textExtensions = @(
        '.cs', '.razor', '.cshtml', '.csproj', '.sln', '.slnx', '.json', '.jsonl',
        '.md', '.txt', '.xml', '.props', '.targets', '.css', '.js', '.html',
        '.yml', '.yaml', '.config', '.http', '.ps1', '.editorconfig', '.gitignore'
    )
    return $File.Extension -in $textExtensions -or $File.Name -in @('.editorconfig', '.gitignore')
}

function Write-ImplementationPatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $WorkspacePath,
        [Parameter(Mandatory)] [string] $PatchPath
    )

    $patch = [Text.StringBuilder]::new()
    $changedFiles = 0
    $addedLines = 0
    $binaryFiles = 0

    $files = Get-ChildItem -LiteralPath $WorkspacePath -Recurse -File | Sort-Object FullName
    foreach ($file in $files) {
        $relativePath = [IO.Path]::GetRelativePath($WorkspacePath, $file.FullName).Replace('\', '/')
        if (Test-BenchmarkExcludedPath -RelativePath $relativePath) { continue }

        $changedFiles++
        [void] $patch.AppendLine("diff --git a/$relativePath b/$relativePath")
        [void] $patch.AppendLine('new file mode 100644')
        [void] $patch.AppendLine('--- /dev/null')
        [void] $patch.AppendLine("+++ b/$relativePath")

        if (-not (Test-BenchmarkTextFile -File $file)) {
            $binaryFiles++
            [void] $patch.AppendLine("Binary files /dev/null and b/$relativePath differ")
            continue
        }

        $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
        if ($content.Length -eq 0) { continue }
        $normalizedContent = $content.Replace("`r`n", "`n").Replace("`r", "`n")
        $lines = $normalizedContent.Split("`n")
        if ($normalizedContent.EndsWith("`n")) {
            $lines = $lines[0..($lines.Length - 2)]
        }
        $lineCount = $lines.Count
        $addedLines += $lineCount
        [void] $patch.AppendLine("@@ -0,0 +1,$lineCount @@")
        foreach ($line in $lines) {
            [void] $patch.AppendLine("+$line")
        }
    }

    Set-Content -LiteralPath $PatchPath -Value $patch.ToString() -Encoding utf8 -NoNewline
    return [pscustomobject]@{
        ChangedFiles = $changedFiles
        AddedLines = $addedLines
        DeletedLines = 0
        BinaryFiles = $binaryFiles
    }
}

function Get-BenchmarkTestCategory {
    param([Parameter(Mandatory)] [string] $TestName)

    if ($TestName -match '(?i)(accessib|a11y|axe)') { return 'accessibility' }
    if ($TestName -match '(?i)(playwright|browser|e2e|endtoend)') { return 'browser' }
    if ($TestName -match '(?i)(component|bunit|blazor|razor)') { return 'blazor' }
    if ($TestName -match '(?i)(concurr|parallel|race|simultaneous)') { return 'concurrency' }
    if ($TestName -match '(?i)(api|endpoint|controller|webapplicationfactory|http)') { return 'api' }
    if ($TestName -match '(?i)(service|domain|business|overlap|adjacent|cancel|inactive|validation)') { return 'businessLogic' }
    return 'uncategorized'
}

function New-TestCategoryResult {
    param([Parameter(Mandatory)] [string] $Name)
    return [ordered]@{ name = $Name; total = 0; passed = 0; failed = 0; skipped = 0 }
}

function Get-BenchmarkTestSummary {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $TestResultsPath)

    $categories = [ordered]@{
        businessLogic = New-TestCategoryResult 'Affärslogik'
        blazor = New-TestCategoryResult 'Blazor och komponenter'
        api = New-TestCategoryResult 'Web API och integration'
        browser = New-TestCategoryResult 'Webbläsarflöden'
        accessibility = New-TestCategoryResult 'Tillgänglighet'
        concurrency = New-TestCategoryResult 'Samtidighet och gränsfall'
        uncategorized = New-TestCategoryResult 'Okategoriserade tester'
    }

    $trxFiles = @(Get-ChildItem -LiteralPath $TestResultsPath -Filter '*.trx' -File -ErrorAction SilentlyContinue)
    foreach ($trxFile in $trxFiles) {
        [xml] $trx = Get-Content -LiteralPath $trxFile.FullName -Raw -Encoding UTF8
        foreach ($result in @($trx.TestRun.Results.UnitTestResult)) {
            if ($null -eq $result) { continue }
            $categoryKey = Get-BenchmarkTestCategory -TestName ([string] $result.testName)
            $category = $categories[$categoryKey]
            $category.total++
            switch ([string] $result.outcome) {
                'Passed' { $category.passed++ }
                { $_ -in @('NotExecuted', 'Skipped', 'Inconclusive') } { $category.skipped++ }
                default { $category.failed++ }
            }
        }
    }

    $total = 0
    $passed = 0
    $failed = 0
    $skipped = 0
    foreach ($category in $categories.Values) {
        $total += $category.total
        $passed += $category.passed
        $failed += $category.failed
        $skipped += $category.skipped
    }
    return [ordered]@{
        schemaVersion = 1
        source = 'trx'
        trxFiles = $trxFiles.Count
        total = $total
        passed = $passed
        failed = $failed
        skipped = $skipped
        categories = $categories
    }
}

function Get-CategoryScore {
    param(
        [Parameter(Mandatory)] $Category,
        [Parameter(Mandatory)] [int] $MaxScore
    )

    $evaluated = $Category.total -gt 0
    $score = if ($evaluated) { [Math]::Round($MaxScore * $Category.passed / $Category.total, 1) } else { 0 }
    return [ordered]@{
        score = $score
        maxScore = $MaxScore
        evaluated = $evaluated
        evidence = "$($Category.passed)/$($Category.total) tester godkända"
    }
}

function Get-ImplementationAssessment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $TestSummary,
        $BuildExitCode,
        $TestExitCode
    )

    $build = [ordered]@{
        score = if ($BuildExitCode -eq 0) { 10 } else { 0 }
        maxScore = 10
        evaluated = $null -ne $BuildExitCode
        evidence = if ($BuildExitCode -eq 0) { 'Lösningen kompilerade; separat startkontroll saknas.' } else { "Build exit $BuildExitCode" }
    }
    $blazorPages = Get-CategoryScore $TestSummary.categories.blazor 15
    $forms = Get-CategoryScore $TestSummary.categories.blazor 10
    $business = Get-CategoryScore $TestSummary.categories.businessLogic 20
    $api = Get-CategoryScore $TestSummary.categories.api 20
    $edgeCases = Get-CategoryScore $TestSummary.categories.concurrency 10
    $accessibility = Get-CategoryScore $TestSummary.categories.accessibility 5
    $quality = [ordered]@{
        score = if ($TestExitCode -eq 0 -and $TestSummary.total -gt 0) { 10 } else { 0 }
        maxScore = 10
        evaluated = $null -ne $TestExitCode -and $TestSummary.total -gt 0
        evidence = if ($TestSummary.total -gt 0) { "$($TestSummary.passed)/$($TestSummary.total) tester godkända; kodkvalitet är inte separat analyserad." } else { 'Inga testresultat registrerade.' }
    }

    $rubric = [ordered]@{
        buildAndStart = $build
        blazorPagesAndFlows = $blazorPages
        formsAndComponentState = $forms
        businessRulesAndValidation = $business
        webApi = $api
        hiddenEdgeCasesAndConcurrency = $edgeCases
        accessibility = $accessibility
        testsQualityAndStructure = $quality
    }
    $score = 0
    $maxScore = 0
    $evaluatedMaxScore = 0
    foreach ($rubricItem in $rubric.Values) {
        $score += $rubricItem.score
        $maxScore += $rubricItem.maxScore
        if ($rubricItem.evaluated) {
            $evaluatedMaxScore += $rubricItem.maxScore
        }
    }

    return [ordered]@{
        schemaVersion = 1
        method = 'observable-v1'
        provisional = $true
        note = 'Preliminär poäng baserad på build och tillgängliga TRX-resultat. Testerna kan vara skapade av modellen och är inte oberoende benchmarktester. Om ett testområde saknas ges 0 poäng; dolda benchmarktester krävs för en slutgiltig bedömning.'
        testCategories = $TestSummary.categories
        partialScores = [ordered]@{
            blazor = [ordered]@{ score = $blazorPages.score + $forms.score; maxScore = 25; evaluated = $blazorPages.evaluated }
            api = [ordered]@{ score = $api.score; maxScore = 20; evaluated = $api.evaluated }
            businessLogic = [ordered]@{ score = $business.score; maxScore = 20; evaluated = $business.evaluated }
        }
        rubric = $rubric
        score = $score
        maxScore = $maxScore
        evaluatedMaxScore = $evaluatedMaxScore
    }
}
