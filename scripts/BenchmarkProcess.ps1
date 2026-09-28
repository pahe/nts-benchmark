function Invoke-BenchmarkProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $FilePath,

        [string[]] $ArgumentList = @(),

        [Parameter(Mandatory)]
        [string] $WorkingDirectory,

        [string] $StandardInput = "",

        [Parameter(Mandatory)]
        [string] $StandardOutputPath,

        [Parameter(Mandatory)]
        [string] $StandardErrorPath,

        [System.Collections.IDictionary] $Environment = @{},

        [Parameter(Mandatory)]
        [TimeSpan] $Timeout
    )

    if ($Timeout -le [TimeSpan]::Zero) {
        throw "Processens tidsgräns måste vara större än noll."
    }

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    foreach ($argument in $ArgumentList) {
        [void] $startInfo.ArgumentList.Add($argument)
    }
    foreach ($key in $Environment.Keys) {
        $startInfo.Environment[[string] $key] = [string] $Environment[$key]
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo

    try {
        if (-not $process.Start()) {
            throw "Kunde inte starta processen '$FilePath'."
        }

        $standardOutputTask = $process.StandardOutput.ReadToEndAsync()
        $standardErrorTask = $process.StandardError.ReadToEndAsync()
        $process.StandardInput.Write($StandardInput)
        $process.StandardInput.Close()

        $timeoutMilliseconds = [int] [Math]::Min([int]::MaxValue, [Math]::Ceiling($Timeout.TotalMilliseconds))
        $timedOut = -not $process.WaitForExit($timeoutMilliseconds)
        if ($timedOut) {
            try {
                $process.Kill($true)
            }
            catch {
                $process.Kill()
            }
            $process.WaitForExit()
        }

        $standardOutput = $standardOutputTask.GetAwaiter().GetResult()
        $standardError = $standardErrorTask.GetAwaiter().GetResult()
        if ($timedOut) {
            $timeoutMessage = "Körningen avbröts efter tidsgränsen $([Math]::Round($Timeout.TotalMinutes, 2)) minuter."
            $standardError = if ($standardError) { "$standardError`r`n$timeoutMessage`r`n" } else { "$timeoutMessage`r`n" }
        }

        Set-Content -LiteralPath $StandardOutputPath -Value $standardOutput -Encoding utf8 -NoNewline
        Set-Content -LiteralPath $StandardErrorPath -Value $standardError -Encoding utf8 -NoNewline

        return [pscustomobject]@{
            ExitCode = if ($timedOut) { 124 } else { $process.ExitCode }
            TimedOut = $timedOut
        }
    }
    finally {
        $process.Dispose()
    }
}
