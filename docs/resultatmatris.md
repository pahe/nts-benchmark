# Resultatmatris

Den första benchmarkspecifikationen definierar 22 resultat som ska registreras. Resultatwebben visar samtliga och redovisar täckningen per körning.

| Resultat | Nuvarande källa eller status |
|---|---|
| Benchmarkläge och variant | Fas och promptversion |
| Start-commit | Saknas eftersom de första körningarna avsiktligt kördes utan Git |
| Modell och exakt modellversion | Modell-ID och Codex-version i `run.json` |
| Datum och tid | `run.json` |
| Systeminstruktion och uppgiftsprompt | Uppgiftsprompt finns; separat systeminstruktion saknas |
| Tillåtna verktyg | Delvis härlett från kommando, isolering och inaktiverade funktioner |
| Maximal körtid | Registreras och verkställs för nya körningar; äldre körningar saknar värdet |
| Antal modellinteraktioner | Härlett från `events.jsonl` |
| In- och utgående tokens | `run.json` |
| Uppskattad kostnad | Saknas |
| Total körtid | `run.json` |
| Antal bygg- och testförsök | Härlett från händelser samt styrskriptets verifiering |
| Antal ändrade filer | Härlett från arbetsytan; implementationsläget börjar tomt |
| Tillagda och borttagna kodrader | `changes.patch` och räknare i `run.json`; äldre körningar kan efterberäknas |
| Byggresultat | Exitkod och `build.log` |
| Resultat per testkategori | Kategoriseras från TRX till affärslogik, Blazor, API, webbläsare, tillgänglighet, samtidighet och okategoriserat |
| Lösta buggrapporter | Inte tillämpligt före buggfixfasen |
| Antal regressioner | Saknas |
| Delpoäng för Blazor, API och affärslogik | Preliminär poäng i `assessment.json`, med explicit uppgift om bedömningsunderlag |
| Slutpoäng | Preliminär automatiserad poäng; dolda benchmarktester krävs för slutgiltig poäng |
| Modellens slutliga kodändring | Arbetsyta, innehållshash och `changes.patch` |
| Modellens sammanfattning | `final-response.md` |

`Saknas` är ett viktigt resultat i sig: det visar att körningen inte innehåller tillräckliga data för en rättvis jämförelse. Den preliminära poängen ger 0 poäng för testområden utan underlag och visar hur stor del av de 100 poängen som faktiskt har bedömts. Den ska inte tolkas som slutgiltig innan benchmarkstyrda och dolda tester finns.
