# Körningsmodell för RoomBooking-benchmark

## 1. Syfte

Detta dokument beskriver hur RoomBooking-benchmarken ska köras från Codex och hur en fullständig benchmarkomgång ska sparas. Målet är att resultaten ska vara isolerade, reproducerbara och möjliga att jämföra utan risk för att tidigare data skrivs över.

En benchmarkomgång består av två huvudfaser:

1. `implementation` – modellen skapar hela RoomBooking-projektet från grunden utifrån kravspecifikationen.
2. `buggfix` – en modell får en kopia av den verifierade implementationen där avsiktliga fel har införts och ska diagnostisera och rätta dem.

Varje omgång får ett GUID som gemensam identitet. Båda arbetsytorna bevaras så att projekten kan öppnas och jämföras sida vid sida.

Den första implementationen ska följa dessa huvudregler:

- ett GUID identifierar hela omgången
- GUID:et skapas en gång och återanvänds för båda faserna
- en befintlig omgång eller fas får aldrig skrivas över
- implementationen och buggfixen körs i separata arbetsytor
- exakt prompt och konfiguration sparas för varje fas
- händelser, kod, tester och resultat bevaras
- buggfixfasen får endast starta från en verifierad och fryst implementation

## 2. Omgångens identitet

Varje benchmarkomgång lagras under:

```text
runs/{GUID}/
```

GUID:et representerar hela kedjan från implementation till buggfix. Det ska skapas när omgången förbereds och därefter skickas explicit till alla kommandon som arbetar med omgången.

Körskriptet får inte automatiskt skapa ett nytt GUID när en befintlig omgång hittas. Om `runs/{GUID}` redan finns ska skapandet av omgången avbrytas. På motsvarande sätt ska en fas avbrytas om den redan har reserverats eller startats.

En ny jämförbar omgång, till exempel samma modell med en annan reasoning-nivå, får ett nytt GUID. Modell, reasoning, promptversion och övrig konfiguration sparas i metadata och används vid analys och gruppering.

En tidsstämpel ingår inte i identiteten. Den sparas endast som metadata.

## 3. Katalogstruktur

```text
runs/
└── {GUID}/
    ├── manifest.json
    ├── README.md
    ├── implementation/
    │   ├── prompt.md
    │   ├── input-files.json
    │   ├── command.txt
    │   ├── run.json
    │   ├── events.jsonl
    │   ├── stderr.log
    │   ├── final-response.md
    │   ├── changes.patch
    │   ├── workspace/
    │   │   └── RoomBooking.sln
    │   └── test-results/
    └── buggfix/
        ├── preparation/
        │   ├── bugs/
        │   ├── changes.patch
        │   └── preparation.json
        ├── input/
        │   └── RoomBooking.sln
        ├── prompt.md
        ├── input-files.json
        ├── command.txt
        ├── run.json
        ├── events.jsonl
        ├── stderr.log
        ├── final-response.md
        ├── changes.patch
        ├── workspace/
        │   └── RoomBooking.sln
        └── test-results/
```

### `manifest.json`

Maskinläsbar innehållsförteckning för hela omgången. Den beskriver omgångens status, konfiguration och var de olika projekten och artefakterna finns.

### `README.md`

Kort människoläsbar sammanfattning med relativa länkar till implementationen, den felaktiga indatan, den rättade arbetsytan, prompterna och testresultaten. Filen ska genereras från `manifest.json` och är inte primär datakälla.

### `implementation/workspace/`

Projektet som implementationsmodellen skapade. När det har verifierats och frysts får det inte ändras. Detta är det ena projektet som kan öppnas vid en jämförelse sida vid sida.

### `buggfix/input/`

En orörd kopia av den frysta implementationen efter att de avsiktliga felen har införts. Den ska aldrig ändras av buggfixmodellen.

### `buggfix/workspace/`

En kopia av `buggfix/input/` som buggfixmodellen får ändra. Detta är det andra projektet som kan öppnas vid en jämförelse sida vid sida.

### `buggfix/preparation/`

Innehåller buggrapporter, privat facit, patchen som införde felen och metadata om hur den felaktiga versionen skapades. Privat material får inte placeras i buggfixmodellens arbetsyta eller prompt.

## 4. `manifest.json`

`manifest.json` ska vara den centrala innehållsförteckningen och kan initialt se ut så här:

```json
{
  "schemaVersion": 1,
  "id": "5f7a6c91-60df-4ee8-a93d-9cab77d49584",
  "createdAtUtc": "2026-09-28T12:00:00Z",
  "description": "RoomBooking från implementation till buggfix",
  "status": "implementation_pending",
  "paths": {
    "implementationWorkspace": "implementation/workspace",
    "implementationPrompt": "implementation/prompt.md",
    "implementationResults": "implementation/test-results",
    "bugfixPreparation": "buggfix/preparation",
    "bugfixInput": "buggfix/input",
    "bugfixWorkspace": "buggfix/workspace",
    "bugfixPrompt": "buggfix/prompt.md",
    "bugfixResults": "buggfix/test-results"
  },
  "phases": {
    "implementation": {
      "status": "pending",
      "model": "gpt-6-sol",
      "reasoningEffort": "high",
      "promptVersion": "implementation-v1",
      "promptSha256": null,
      "referenceCommit": null
    },
    "bugfix": {
      "status": "blocked",
      "model": null,
      "reasoningEffort": null,
      "promptVersion": "buggfix-v1",
      "promptSha256": null,
      "inputCommit": null
    }
  }
}
```

Tillåtna fasstatusar är:

- `pending`
- `blocked`
- `running`
- `completed`
- `failed`
- `interrupted`

Buggfixfasen har status `blocked` tills implementationen har byggts, testats och frysts samt en godkänd felversion har skapats.

Manifestet ska skrivas atomärt genom att först skriva en temporär fil och därefter ersätta den befintliga filen.

## 5. Prompter och övriga indata

Prompten kan påverka resultatet lika mycket som modell och reasoning-nivå. Därför ska varje fas spara den exakta prompt som faktiskt skickades till Codex.

### `prompt.md`

Filen ska innehålla den slutligt renderade prompten efter att alla mallvariabler har ersatts. Det räcker inte att enbart spara promptmallen.

Om prompten instruerar modellen att läsa krav, buggrapporter eller andra filer ska den exakta prompttexten fortfarande sparas. De refererade filernas sökvägar och SHA-256-hashar registreras i `input-files.json`.

En ändrad prompttext eller ändrad indata räknas som en ändrad experimentkonfiguration, även om modell och reasoning-nivå är oförändrade.

### `input-files.json`

Filen ska registrera alla versionsbundna filer som kan påverka modellen, exempelvis:

- kravspecifikationen
- synliga buggrapporter
- startfiler och testprojekt
- `AGENTS.md` och andra projektinstruktioner
- explicit aktiverade skills eller andra instruktioner

Exempel:

```json
{
  "schemaVersion": 1,
  "files": [
    {
      "path": "docs/room-booking-benchmark.md",
      "sha256": "<hash>"
    }
  ]
}
```

### Konfiguration som också ska sparas

Förutom prompten ska följande registreras:

- exakt modellnamn
- reasoning-nivå
- Codex-version
- .NET SDK-version
- start-commit eller annan exakt startversion
- Codex-kommandot och samtliga argument
- sandbox- och godkännandepolicy
- aktiverade verktyg och nätverksåtkomst
- maximal körtid
- miljöinformation som behövs för att upprepa körningen

Autentiseringsuppgifter, åtkomsttoken och andra hemligheter får aldrig sparas.

## 6. Skydd mot dubbelkörning

Omgången och varje fas ska reserveras atomärt.

När en ny omgång skapas ska styrskriptet använda en operation som misslyckas om målkatalogen eller en reserveringsfil redan finns, exempelvis .NET-läget `FileMode.CreateNew`.

Flödet för en ny omgång är:

1. Ta emot och validera GUID:et.
2. Beräkna sökvägen `runs/{GUID}`.
3. Försök skapa en exklusiv reservering för GUID:et.
4. Avbryt om reserveringen eller resultatkatalogen redan finns.
5. Skapa katalogstrukturen och initialt manifest.

Flödet för en fas är:

1. Kontrollera att omgången finns.
2. Kontrollera att fasens förutsättningar är uppfyllda.
3. Försök skapa en exklusiv fasreservering.
4. Avbryt om fasen redan har reserverats eller startats.
5. Skriv `run.json` med status `running` innan Codex startas.

Reserveringar ska behållas även efter lyckade, misslyckade eller avbrutna körningar. En återställning är en uttrycklig administrativ åtgärd. Styrskriptet får inte automatiskt fortsätta, skriva över eller välja ett nytt GUID.

## 7. Implementationsfasen

Implementationsfasen börjar i en tom och isolerad arbetsyta som innehåller den indata modellen uttryckligen ska få, exempelvis kravspecifikationen och eventuella synliga tester. Den innehåller inte någon färdig RoomBooking-applikation.

Modellen ska skapa hela lösningen från grunden i `implementation/workspace/`.

Efter Codex-körningen ska styrskriptet:

1. spara modellens slutliga arbetsyta
2. bygga lösningen
3. köra samtliga tillåtna verifieringstester
4. spara testresultaten
5. exportera ändringarna som en binärsäker patch
6. registrera slutligt commit-ID eller innehållshash
7. markera implementationen som fryst om verifieringen godkänns

Om implementationen inte klarar den verifiering som krävs för att bli referens ska buggfixfasen förbli blockerad. Resultatet ska ändå bevaras som en misslyckad eller ofullständig körning.

## 8. Förberedelse av buggfixfasen

När implementationen är verifierad och fryst skapas buggfixunderlaget enligt följande:

1. Kopiera den frysta implementationen till en separat förberedelsearbetsyta.
2. Inför två eller tre avsiktliga, reproducerbara fel.
3. Skapa användarinriktade buggrapporter.
4. Spara privat facit och patch under `buggfix/preparation/`.
5. Verifiera att projektet fortfarande bygger.
6. Verifiera att relevanta buggspecifika tester misslyckas.
7. Kopiera den godkända felversionen till `buggfix/input/`.
8. Gör `buggfix/input/` skrivskyddad för den kommande modellkörningen.

Fel kan införas manuellt eller av en separat buggmodell. Om en modell används ska även dess prompt, modellkonfiguration, händelsespår och resultat sparas under `buggfix/preparation/`.

## 9. Buggfixfasen

Före buggfixkörningen kopieras `buggfix/input/` till `buggfix/workspace/`. Buggfixmodellen får endast skriva i arbetsytan.

Modellen får tillgång till:

- den felaktiga koden
- användarinriktade buggrapporter
- tillåtna synliga tester
- den exakta buggfixprompten

Modellen får inte tillgång till:

- privat facit
- patchen som införde felen
- dolda tester
- referenskorrigeringar

Efter körningen ska samma typ av artefakter samlas in som för implementationsfasen. `buggfix/input/` och `buggfix/workspace/` ska båda bevaras så att den ursprungliga felversionen och modellens lösning kan jämföras.

## 10. Metadata i fasens `run.json`

Varje fas har en egen `run.json` med minst följande information:

```json
{
  "schemaVersion": 1,
  "experimentId": "5f7a6c91-60df-4ee8-a93d-9cab77d49584",
  "phase": "implementation",
  "status": "running",
  "model": "gpt-6-sol",
  "reasoningEffort": "high",
  "promptPath": "prompt.md",
  "promptVersion": "implementation-v1",
  "promptSha256": "<hash>",
  "inputFilesPath": "input-files.json",
  "startedAtUtc": "<ISO 8601>",
  "completedAtUtc": null,
  "durationSeconds": null,
  "codexVersion": "<version>",
  "dotnetVersion": "<version>",
  "workspacePath": "workspace",
  "exitCode": null,
  "inputTokens": null,
  "outputTokens": null,
  "reasoningTokens": null
}
```

Metadata ska uppdateras atomärt när fasen avslutas.

## 11. Artefakter som ska sparas per fas

### `prompt.md`

Den exakta slutliga prompten som skickades till modellen.

### `input-files.json`

Sökväg och SHA-256 för varje versionsbunden indatafil som modellen kunde påverkas av.

### `command.txt`

Det exakta Codex-kommandot och dess argument, utan hemligheter.

### `events.jsonl`

Hela det strukturerade händelseflödet från `codex exec --json`. OpenAI Docs rekommenderar JSONL-spåret för eval-körningar eftersom det gör det möjligt att kontrollera vilka kommandon och verktygssteg som faktiskt utfördes, inte bara slutmeddelandet.

### `stderr.log`

Diagnostik och felutskrifter från Codex-processen.

### `final-response.md`

Modellens sista svar.

### `changes.patch`

Alla kodändringar jämfört med fasens startversion, inklusive nya och binära filer.

### `workspace/`

Den fullständiga slutliga arbetsytan. Den bevaras för inspektion och jämförelse sida vid sida.

### `test-results/`

Byggresultat, testresultat och eventuella TRX-, JUnit- eller Playwright-artefakter. Testerna ska köras av benchmarkens styrskript efter Codex-körningen så att alla modeller bedöms med samma kommandon och tidsgränser.

## 12. Codex-anrop

Den installerade Codex-versionens `codex exec --help` är styrande för exakt syntax. Ett initialt anrop kan utformas enligt följande:

```powershell
codex --no-daemon exec `
  --ignore-user-config `
  --skip-git-repo-check `
  --enable skip_host_skill_discovery `
  --disable plugins `
  --disable apps `
  --disable multi_agent `
  --model gpt-6-sol `
  -c 'model_reasoning_effort="high"' `
  --json `
  --output-last-message '<phase-path>/final-response.md' `
  --cd '<phase-path>/workspace' `
  --approve-for-me `
  '<prompt>'
```

Standard output ska styras till `events.jsonl` och standard error till `stderr.log`.

`--no-daemon` startar körningen utan den delade lokala daemonen så att dess tidigare sessionstillstånd inte påverkar benchmarken. Körskriptet sätter dessutom `CODEX_HOME` till en tillfällig katalog som endast innehåller en kopia av autentiseringsfilen. Den tillfälliga katalogen ligger utanför run-artefakterna och tas bort efter processen. Därmed exponeras inte personliga skills, plugins, regler, minnen eller konfiguration för modellen. Autentiseringsfilen får aldrig loggas, hashas in i manifestet eller sparas i run-mappen.

`--ignore-user-config` används som ett ytterligare skydd mot personlig konfiguration. `skip_host_skill_discovery` hindrar host-skills från att läggas till, och plugins, appar samt multi-agent-funktioner stängs av i standardkörningen. Alla avsedda instruktioner och verktyg ska vara versionsbundna och registrerade i `input-files.json` eller `run.json`. Eftersom benchmarkarbetsytorna avsiktligt saknar Git-metadata används `--skip-git-repo-check`. `--approve-for-me` använder Codex arbetsytesandbox och får i den installerade CLI-versionen inte kombineras med ett separat `--sandbox`-argument.

Reasoning-nivån ska alltid anges explicit. Benchmarken får inte vara beroende av modellens eller Codex-versionens standardvärde.

## 13. Fullständigt körningsförlopp

1. Skapa ett GUID för den nya omgången.
2. Reservera GUID:et och skapa `runs/{GUID}`.
3. Skapa initialt `manifest.json` och `README.md`.
4. Rendera och spara implementationens exakta prompt.
5. Registrera och hasha samtliga indatafiler.
6. Skapa den tomma implementationsarbetsytan.
7. Kör Codex och samla alla implementationsartefakter.
8. Bygg, testa och bedöm implementationen.
9. Frys den godkända implementationen.
10. Skapa och verifiera en felaktig version.
11. Bevara felversionen i `buggfix/input/`.
12. Rendera och spara buggfixens exakta prompt.
13. Registrera och hasha buggfixens indatafiler.
14. Kopiera felversionen till `buggfix/workspace/`.
15. Kör Codex och samla alla buggfixartefakter.
16. Bygg, testa och bedöm buggfixresultatet.
17. Uppdatera `manifest.json`, fasernas `run.json` och `README.md`.

Om styrskriptet kraschar ska ett nytt försök med samma GUID hitta reserveringen och avbryta. Den ofullständiga omgången kan analyseras utan att dess data skrivs över.

## 14. Projekt som öppnas sida vid sida

För en färdig omgång kan följande mappar öppnas i två separata editorfönster:

```text
runs/{GUID}/implementation/workspace
runs/{GUID}/buggfix/workspace
```

Vid analys av själva felrättningen kan i stället följande jämföras:

```text
runs/{GUID}/buggfix/input
runs/{GUID}/buggfix/workspace
```

## 15. Rekommenderad första implementation

Den första versionen bör bestå av separata PowerShell-kommandon eller skript för omgångens livscykel:

```text
scripts/New-BenchmarkRun.ps1
scripts/Start-Implementation.ps1
scripts/Prepare-Bugfix.ps1
scripts/Start-Bugfix.ps1
```

Alla skript ska ta GUID:et explicit. Startskripten ska dessutom ta modell, reasoning-nivå, promptfil och maximal körtid som explicita parametrar.

Inget skript får automatiskt välja ett nytt GUID, återanvända en arbetsyta eller skriva över befintliga artefakter.

## 16. Källor

- [OpenAI: Testing Agent Skills Systematically with Evals](https://developers.openai.com/blog/eval-skills) – beskriver en eval som prompt, fångad körning, artefakter, kontroller och poäng samt rekommenderar `codex exec --json` och sparade JSONL-spår.
- [OpenAI: Reasoning models](https://developers.openai.com/api/docs/guides/reasoning) – beskriver reasoning-nivåer och varför nivån ska anges och registreras uttryckligen i jämförbara körningar.
