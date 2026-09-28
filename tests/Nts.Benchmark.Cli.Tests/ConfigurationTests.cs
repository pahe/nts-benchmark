using Nts.Benchmark.Cli;
using Xunit;

namespace Nts.Benchmark.Cli.Tests;

public sealed class ConfigurationTests
{
    [Fact]
    public void Catalog_contains_unique_models_and_efforts()
    {
        var root = RepositoryLocator.Find(AppContext.BaseDirectory);
        var catalog = ModelCatalog.Load(Path.Combine(root, "config", "codex-models.json"));
        Assert.NotEmpty(catalog.Models);
        Assert.Equal(catalog.Models.Count, catalog.Models.Select(model => model.Id).Distinct().Count());
        Assert.All(catalog.Models, model => Assert.Equal(model.ReasoningEfforts.Count, model.ReasoningEfforts.Distinct().Count()));
    }

    [Fact]
    public void Start_arguments_keep_values_as_separate_process_arguments()
    {
        var id = Guid.NewGuid();
        var configuration = new RunConfiguration(id, "implementation", "gpt-6-sol", "medium", "prompts/a prompt.md", 30);
        var arguments = RunCommandFactory.StartArguments(configuration);
        Assert.Contains("prompts/a prompt.md", arguments);
        Assert.Equal("30", arguments[^1]);
        Assert.Equal("-PromptPath", arguments[^4]);
        Assert.Equal("prompts/a prompt.md", arguments[^3]);
    }

    [Fact]
    public void Bugfix_uses_the_dedicated_script()
    {
        var configuration = new RunConfiguration(Guid.NewGuid(), "buggfix", "gpt-6-sol", "medium", "prompts/buggfix-v1.md", 30);
        Assert.Contains("scripts/Start-Bugfix.ps1", RunCommandFactory.StartArguments(configuration));
    }
}
