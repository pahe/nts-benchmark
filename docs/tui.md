# Benchmark-TUI

TUI:t är ett tunt C#-gränssnitt ovanpå benchmarkens PowerShell-skript. Det väljer inställningar, skapar ett nytt GUID och startar skripten med separata processargument. Körlogik, låsning, timeout, Codex-anrop och artefakter ligger fortsatt i PowerShell-skripten.

## Förutsättningar

- Windows PowerShell eller PowerShell 7 (`pwsh`)
- .NET SDK 10
- Codex CLI installerat och inloggat
- Python om den lokala resultatsidan ska startas

Kontrollera Codex-inloggningen med `codex --version` och vid behov den vanliga Codex-inloggningen innan en betald körning startas.

## Restore och build

Kör från reporoten:

```powershell
dotnet restore ./tests/Nts.Benchmark.Cli.Tests/Nts.Benchmark.Cli.Tests.csproj --disable-parallel
dotnet build ./Nts.Benchmark.slnx --no-restore
dotnet test ./Nts.Benchmark.slnx --no-restore
```

## Starta verktyget

Det enklaste startkommandot är:

```powershell
./Start-Benchmark.ps1
```

En kontroll som inte startar någon benchmarkkörning kan göras med:

```powershell
./Start-Benchmark.ps1 -Check
```

Direkt start utan hjälpskript:

```powershell
dotnet run --project ./src/Nts.Benchmark.Cli/Nts.Benchmark.Cli.csproj
```

## Exempel: implementationskörning

1. Starta `./Start-Benchmark.ps1`.
2. Välj `implementation`.
3. Välj exempelvis `gpt-5.6-luna`.
4. Välj `medium` reasoning effort.
5. Välj `prompts/implementation-v1.md`.
6. Behåll timeout `30` minuter.
7. Kontrollera sammanfattningen och bekräfta starten.

TUI:t skapar ett nytt GUID och kör därefter motsvarande:

```powershell
./scripts/New-BenchmarkRun.ps1 -Id <GUID>
./scripts/Start-Implementation.ps1 -Id <GUID> -Model gpt-5.6-luna -ReasoningEffort medium -PromptPath prompts/implementation-v1.md -TimeoutMinutes 30
```

GUID återanvänds aldrig. De befintliga skripten och reservationsfilerna gör dessutom samma kontroll atomiskt.

Resultatet sparas under `runs/{GUID}/implementation/`, inklusive prompt, händelser, loggar, kod, testresultat, `changes.patch` och `assessment.json`.

## Modellkatalog och val

Modeller och tillåtna reasoning-nivåer finns versionshanterade i `config/codex-models.json`. TUI:t filtrerar reasoning-valet efter vald modell. Katalogen beskriver vad benchmarkverktyget erbjuder, inte vad det aktuella kontot garanterat har åtkomst till. Codex verifierar den valda modellen när den verkliga körningen startar.

`IModelCatalogProvider` gör att en framtida provider kan läsa `GET /models` utan att ändra TUI-flödet. Den versionen kan också användas av framtida körmatriser. Första versionen använder endast JSON-katalogen och startar en körning åt gången.

## Resultatsidan

Efter en lyckad körning erbjuder TUI:t att starta och öppna resultatsidan. Den kan också öppnas separat:

```powershell
./scripts/Serve-ResultsSite.ps1
```

Gå till `http://127.0.0.1:4173/`.

## Vanliga fel

- **Codex-inloggning saknas:** kör Codex inloggningsflöde och kontrollera att `%USERPROFILE%\.codex\auth.json` finns. Körningen avbryts med ett begripligt fel och loggen finns i omgångens `stderr.log`.
- **Modellen är inte tillgänglig:** välj en annan modell i katalogen eller kontrollera kontoåtkomsten. TUI:t kan inte lista kontots modeller genom Codex CLI och låter därför det riktiga Codex-anropet verifiera valet.
- **Timeout:** Codex-processen stoppas efter vald gräns, `timedOut` blir `true` i `run.json` och exitkoden blir 124. Delvis skapad kod och loggar bevaras.
- **Buggfix är inte startbart ännu:** valet visas för att göra flödet tydligt, men TUI:t skapar ingen omgång förrän `Start-Bugfix.ps1` finns och buggfixförberedelsen är implementerad.

Reasoning effort är modellberoende. Den officiella OpenAI-dokumentationen beskriver bland annat `none`, `minimal`, `low`, `medium`, `high`, `xhigh` och `max`, samt att stöd och standardvärden varierar mellan modeller: https://developers.openai.com/api/docs/guides/reasoning
