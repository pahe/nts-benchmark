# nts-benchmark

RoomBooking-benchmark för kodande språkmodeller.

## Interaktiv start

Det interaktiva C#-verktyget väljer modell, reasoning effort, prompt och timeout och visar en sammanfattning innan ett nytt GUID skapas:

```powershell
dotnet restore ./tests/Nts.Benchmark.Cli.Tests/Nts.Benchmark.Cli.Tests.csproj --disable-parallel
./Start-Benchmark.ps1
```

Kontrollera installationen utan att starta en betald körning med `./Start-Benchmark.ps1 -Check`. Fullständiga instruktioner, ett konkret exempel och felsökning finns i `docs/tui.md`.

## Standardkörning

Standardkonfigurationen finns i `config/defaults.json`. En ny implementationsomgång skapas och startas från PowerShell:

```powershell
$id = [Guid]::NewGuid()
./scripts/New-BenchmarkRun.ps1 -Id $id
./scripts/Start-Implementation.ps1 -Id $id
```

Det andra kommandot använder som standard `gpt-6-sol` med reasoning-nivån `medium` och stoppar Codex-processen efter högst 30 minuter. Gränsen kan ändras per körning med `-TimeoutMinutes`. Körningens prompt, händelsespår, slutmeddelande, kod och testresultat sparas under `runs/{GUID}/implementation/`.

Ett GUID får inte återanvändas. Skripten avbryter om omgången eller implementationsfasen redan finns.

Efter körningen skapas `changes.patch`, en kategoriserad testsammanfattning och `assessment.json`. Bedömningen är preliminär tills benchmarkstyrda och dolda tester har lagts till; områden utan testunderlag får 0 poäng och täckningen redovisas separat. Befintliga körningar kan uppdateras med `./scripts/Update-RunArtifacts.ps1`.

Se `docs/benchmark-korningar.md` för den fullständiga körningsmodellen.

## Jämför resultat i webbläsaren

Resultatwebben visar två körningar sida vid sida med manifest, filträd och syntaxmarkerad kod:

```powershell
./scripts/Serve-ResultsSite.ps1
```

Öppna `http://127.0.0.1:4173`. Webbplatsen är helt statisk och förberedd för att kunna publiceras från `site/` med GitHub Pages senare. Se `docs/resultatwebb.md` för datagenerering, filtrering och publiceringsinformation.

Skapa en sanerad GitHub Pages-export i `dist/` med `./scripts/Build-PublicResultsSite.ps1`. Publicera inte den lokala `site/data/` direkt.
