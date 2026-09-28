using System.Diagnostics;
using Spectre.Console;

namespace Nts.Benchmark.Cli;

public static class Program
{
    public static async Task<int> Main(string[] args)
    {
        try
        {
            var repositoryRoot = RepositoryLocator.Find(Environment.CurrentDirectory);
            var catalogPath = Path.Combine(repositoryRoot, "config", "codex-models.json");
            IModelCatalogProvider catalogProvider = new JsonModelCatalogProvider(catalogPath);
            var catalog = catalogProvider.GetCatalog();
            var powershell = FindExecutable("pwsh") ?? FindExecutable("powershell")
                ?? throw new FileNotFoundException("PowerShell (pwsh eller powershell) saknas.");

            if (args.Contains("--check", StringComparer.OrdinalIgnoreCase))
            {
                AnsiConsole.MarkupLine($"[green]OK[/] · {catalog.Models.Count} modeller · [grey]{Markup.Escape(repositoryRoot)}[/]");
                return 0;
            }

            AnsiConsole.Write(new FigletText("NTS Benchmark").Color(Color.Teal));
            var mode = AnsiConsole.Prompt(new SelectionPrompt<string>()
                .Title("Välj [teal]körningsläge[/]")
                .AddChoices("implementation", "buggfix"));
            var startScript = Path.Combine(repositoryRoot, "scripts", mode == "implementation" ? "Start-Implementation.ps1" : "Start-Bugfix.ps1");
            if (!File.Exists(startScript))
            {
                AnsiConsole.MarkupLine("[yellow]Buggfixläget är förberett men startskriptet finns ännu inte. Ingen omgång skapades.[/]");
                return 2;
            }

            var model = AnsiConsole.Prompt(new SelectionPrompt<ModelDefinition>()
                .Title("Välj [teal]Codex-modell[/]")
                .UseConverter(item => item.Id)
                .AddChoices(catalog.Models));
            var reasoning = AnsiConsole.Prompt(new SelectionPrompt<string>()
                .Title("Välj [teal]reasoning effort[/]")
                .AddChoices(model.ReasoningEfforts));
            var prompts = Directory.GetFiles(Path.Combine(repositoryRoot, "prompts"), "*.md")
                .Select(path => Path.GetRelativePath(repositoryRoot, path).Replace('\\', '/'))
                .OrderBy(path => path)
                .ToArray();
            var prompt = AnsiConsole.Prompt(new SelectionPrompt<string>()
                .Title("Välj [teal]prompt[/]")
                .AddChoices(prompts));
            var timeout = AnsiConsole.Prompt(new TextPrompt<int>("Timeout i minuter")
                .DefaultValue(30)
                .ValidationErrorMessage("Ange 1–1440 minuter.")
                .Validate(value => value is >= 1 and <= 1440));

            Guid id;
            do { id = Guid.NewGuid(); }
            while (Directory.Exists(Path.Combine(repositoryRoot, "runs", id.ToString())) ||
                   File.Exists(Path.Combine(repositoryRoot, "runs", ".reservations", $"{id}.lock")));
            var configuration = new RunConfiguration(id, mode, model.Id, reasoning, prompt, timeout);

            var table = new Table().Border(TableBorder.Rounded).AddColumn("Inställning").AddColumn("Värde");
            table.AddRow("ID", id.ToString());
            table.AddRow("Läge", mode);
            table.AddRow("Modell", Markup.Escape(model.Id));
            table.AddRow("Reasoning", reasoning);
            table.AddRow("Prompt", Markup.Escape(prompt));
            table.AddRow("Timeout", $"{timeout} minuter");
            AnsiConsole.Write(table);
            AnsiConsole.MarkupLine("[grey]Modelltillgänglighet verifieras av Codex när körningen startar.[/]");
            if (!AnsiConsole.Confirm("Starta körningen?")) return 0;

            var runner = new ProcessRunner();
            var createExit = await runner.RunAsync(powershell, RunCommandFactory.NewRunArguments(configuration), repositoryRoot, WriteProcessLine);
            if (createExit != 0) return ReportFailure("Omgången kunde inte skapas", createExit);

            var startExit = await runner.RunAsync(powershell, RunCommandFactory.StartArguments(configuration), repositoryRoot, WriteProcessLine);
            if (startExit != 0)
            {
                AnsiConsole.MarkupLine("[red]Körningen misslyckades.[/] Kontrollera Codex-inloggning, modellåtkomst och stderr.log i omgångens mapp.");
                return startExit;
            }

            AnsiConsole.MarkupLine($"[green]Klar.[/] Resultatet finns i [grey]runs/{id}/[/]");
            if (AnsiConsole.Confirm("Öppna resultatsidan?")) OpenResults(repositoryRoot, powershell);
            return 0;
        }
        catch (Exception exception)
        {
            AnsiConsole.MarkupLine($"[red]Fel:[/] {Markup.Escape(exception.Message)}");
            return 1;
        }
    }

    private static void WriteProcessLine(string line, bool error) =>
        AnsiConsole.MarkupLine(error ? $"[red]{Markup.Escape(line)}[/]" : Markup.Escape(line));

    private static int ReportFailure(string message, int exitCode)
    {
        AnsiConsole.MarkupLine($"[red]{Markup.Escape(message)}[/] (exit {exitCode}).");
        return exitCode;
    }

    private static string? FindExecutable(string name)
    {
        var extension = OperatingSystem.IsWindows() ? ".exe" : string.Empty;
        foreach (var directory in (Environment.GetEnvironmentVariable("PATH") ?? string.Empty).Split(Path.PathSeparator))
        {
            var candidate = Path.Combine(directory, name + extension);
            if (File.Exists(candidate)) return candidate;
        }
        return null;
    }

    private static void OpenResults(string repositoryRoot, string powershell)
    {
        Process.Start(new ProcessStartInfo(powershell)
        {
            WorkingDirectory = repositoryRoot,
            UseShellExecute = false,
            CreateNoWindow = true,
            WindowStyle = ProcessWindowStyle.Hidden,
            ArgumentList = { "-NoProfile", "-File", "scripts/Serve-ResultsSite.ps1" }
        });
        Thread.Sleep(800);
        Process.Start(new ProcessStartInfo("http://127.0.0.1:4173/") { UseShellExecute = true });
    }
}
