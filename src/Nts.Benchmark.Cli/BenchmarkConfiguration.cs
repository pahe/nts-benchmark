using System.Text.Json;

namespace Nts.Benchmark.Cli;

public sealed record ModelDefinition(string Id, IReadOnlyList<string> ReasoningEfforts);

public sealed record ModelCatalog(int SchemaVersion, string Source, IReadOnlyList<ModelDefinition> Models)
{
    public static ModelCatalog Load(string path)
    {
        var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
        var catalog = JsonSerializer.Deserialize<ModelCatalog>(File.ReadAllText(path), options)
            ?? throw new InvalidDataException($"Modellkatalogen kunde inte läsas: {path}");
        if (catalog.SchemaVersion != 1 || catalog.Models.Count == 0 ||
            catalog.Models.Any(model => string.IsNullOrWhiteSpace(model.Id) || model.ReasoningEfforts.Count == 0))
        {
            throw new InvalidDataException("Modellkatalogen har ogiltigt format.");
        }
        return catalog;
    }
}

public interface IModelCatalogProvider
{
    ModelCatalog GetCatalog();
}

public sealed class JsonModelCatalogProvider(string path) : IModelCatalogProvider
{
    public ModelCatalog GetCatalog() => ModelCatalog.Load(path);
}

public sealed record RunConfiguration(
    Guid Id,
    string Mode,
    string Model,
    string ReasoningEffort,
    string PromptPath,
    int TimeoutMinutes);

public static class RepositoryLocator
{
    public static string Find(string startPath)
    {
        var directory = new DirectoryInfo(Path.GetFullPath(startPath));
        while (directory is not null)
        {
            if (File.Exists(Path.Combine(directory.FullName, "scripts", "New-BenchmarkRun.ps1")) &&
                File.Exists(Path.Combine(directory.FullName, "config", "codex-models.json")))
            {
                return directory.FullName;
            }
            directory = directory.Parent;
        }
        throw new DirectoryNotFoundException("Kunde inte hitta nts-benchmark-roten.");
    }
}

public static class RunCommandFactory
{
    public static IReadOnlyList<string> NewRunArguments(RunConfiguration configuration) =>
    ["-NoProfile", "-File", "scripts/New-BenchmarkRun.ps1", "-Id", configuration.Id.ToString()];

    public static IReadOnlyList<string> StartArguments(RunConfiguration configuration)
    {
        var script = configuration.Mode == "implementation"
            ? "scripts/Start-Implementation.ps1"
            : "scripts/Start-Bugfix.ps1";
        return [
            "-NoProfile", "-File", script,
            "-Id", configuration.Id.ToString(),
            "-Model", configuration.Model,
            "-ReasoningEffort", configuration.ReasoningEffort,
            "-PromptPath", configuration.PromptPath,
            "-TimeoutMinutes", configuration.TimeoutMinutes.ToString()
        ];
    }
}
