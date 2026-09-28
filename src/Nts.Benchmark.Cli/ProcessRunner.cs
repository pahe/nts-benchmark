using System.Diagnostics;

namespace Nts.Benchmark.Cli;

public sealed class ProcessRunner
{
    public async Task<int> RunAsync(
        string executable,
        IReadOnlyList<string> arguments,
        string workingDirectory,
        Action<string, bool> onLine,
        CancellationToken cancellationToken = default)
    {
        var startInfo = new ProcessStartInfo(executable)
        {
            WorkingDirectory = workingDirectory,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };
        foreach (var argument in arguments)
        {
            startInfo.ArgumentList.Add(argument);
        }

        using var process = new Process { StartInfo = startInfo, EnableRaisingEvents = true };
        process.OutputDataReceived += (_, eventArgs) => { if (eventArgs.Data is not null) onLine(eventArgs.Data, false); };
        process.ErrorDataReceived += (_, eventArgs) => { if (eventArgs.Data is not null) onLine(eventArgs.Data, true); };
        if (!process.Start()) throw new InvalidOperationException($"Kunde inte starta {executable}.");
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();
        await process.WaitForExitAsync(cancellationToken);
        return process.ExitCode;
    }
}
