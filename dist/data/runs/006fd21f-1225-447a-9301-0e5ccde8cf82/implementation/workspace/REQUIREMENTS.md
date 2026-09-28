# RoomBooking – benchmark för kodande språkmodeller

## 1. Bakgrund och syfte

RoomBooking är ett benchmark för att utvärdera hur väl en språkmodell kan arbeta som C#-utvecklare i en befintlig kodbas.

Benchmarken utgår från en mindre Blazor-applikation för bokning av mötesrum. Modellen får tillgång till projektets källkod och ska antingen:

1. slutföra en ofullständig applikation utifrån en kravspecifikation, eller
2. diagnostisera och rätta rapporterade fel i en färdig applikation.

Applikationen ska dessutom tillhandahålla ett Web API som externa klienter, exempelvis en mobilapp, kan använda.

Benchmarken ska mäta mer än modellens förmåga att generera en isolerad funktion. Den ska pröva om modellen kan:

- förstå strukturen i en befintlig .NET-lösning
- tolka och omsätta verksamhetskrav
- navigera och söka i en kodbas
- implementera funktionalitet i flera lager
- bygga ett användargränssnitt med Blazor
- bygga ett stabilt HTTP-API
- förstå och reproducera buggrapporter
- lokalisera bakomliggande orsaker till fel
- göra begränsade och korrekta kodändringar
- hantera validering, samtidighet och gränsfall
- bevara befintlig funktionalitet
- använda byggfel och testresultat för att förbättra lösningen

Resultatet ska i första hand bedömas automatiskt genom kompilering, enhetstester, komponenttester, integrationstester och webbläsartester.

---

## 2. Benchmarklägen

### 2.1 Läge A: slutför applikationen

Modellen får ett ofullständigt startprojekt tillsammans med denna kravspecifikation. Delar av applikationen kan saknas, innehålla tomma metoder eller vara markerade som ännu inte implementerade.

Modellen ska färdigställa lösningen så att samtliga obligatoriska krav och tester uppfylls.

Detta läge mäter främst modellens förmåga att:

- planera en implementation
- arbeta i flera filer och lager
- implementera affärsregler
- skapa Blazor-komponenter och formulär
- bygga ett Web API
- verifiera sitt arbete

### 2.2 Läge B: diagnostisera och rätta fel

Modellen får en i huvudsak färdig version av webbplatsen där två eller tre fel har införts avsiktligt.

Till varje fel hör en buggrapport som beskriver observerat beteende. Rapporten ska inte avslöja den tekniska orsaken eller vilken fil som behöver ändras.

Modellen ska:

1. läsa buggrapporterna
2. undersöka lösningen
3. försöka reproducera problemen
4. identifiera bakomliggande orsaker
5. rätta felen
6. kontrollera att befintlig funktionalitet fortfarande fungerar
7. lägga till regressionstester när det är lämpligt
8. sammanfatta vad som ändrats och hur resultatet verifierats

Resultaten från de två benchmarklägena ska redovisas separat.

---

## 3. Applikationsöversikt

RoomBooking är en webbplats där användare kan se och boka mötesrum.

Applikationen ska innehålla följande huvudvyer:

1. en lista över bokningar
2. ett formulär för att skapa en bokning
3. en detaljsida för en bokning
4. ett formulär för att redigera en bokning

Från detaljsidan ska en bokning även kunna avbokas.

Applikationen behöver inte innehålla inloggning eller avancerad behörighetshantering. Fokus ligger på korrekt affärslogik, Blazor-komponenter, API-design, validering och felsökning.

---

## 4. Teknisk miljö

Projektet ska använda:

- C#
- .NET 8 eller senare
- ASP.NET Core Blazor Web App
- Interactive Server-rendering
- Entity Framework Core
- SQLite
- `IDbContextFactory<TContext>` för kortlivade databaskontexter
- xUnit, NUnit eller MSTest
- bUnit där komponenttester är lämpliga
- Playwright för webbläsartester
- `WebApplicationFactory` för API-integrationstester

MVC-vyer och Razor Pages ska inte användas för applikationens användargränssnitt. Gränssnittet ska implementeras med routningsbara Blazor-komponenter och återanvändbara underkomponenter.

Applikationen ska kunna byggas och testas med:

```text
dotnet build
dotnet test
```

Databasen ska kunna skapas automatiskt vid testning. Benchmarken får inte vara beroende av en externt installerad databasserver.

---

## 5. Föreslagen projektstruktur

```text
RoomBooking/
├── RoomBooking.Web/
│   ├── Api/
│   │   ├── BookingEndpoints.cs
│   │   └── RoomEndpoints.cs
│   ├── Components/
│   │   ├── Layout/
│   │   ├── Pages/
│   │   │   ├── Bookings.razor
│   │   │   ├── CreateBooking.razor
│   │   │   ├── BookingDetails.razor
│   │   │   └── EditBooking.razor
│   │   ├── BookingForm.razor
│   │   ├── BookingList.razor
│   │   └── StatusMessage.razor
│   ├── Contracts/
│   │   ├── Bookings/
│   │   └── Rooms/
│   ├── Data/
│   │   ├── RoomBookingDbContext.cs
│   │   └── DatabaseSeeder.cs
│   ├── Models/
│   ├── Services/
│   ├── ViewModels/
│   ├── wwwroot/
│   ├── App.razor
│   ├── Routes.razor
│   └── Program.cs
├── RoomBooking.Tests/
├── RoomBooking.ComponentTests/
├── RoomBooking.ApiTests/
├── RoomBooking.PlaywrightTests/
├── RoomBooking.sln
└── README.md
```

Den exakta strukturen får variera, men presentation, API-kontrakt, affärslogik och databasåtkomst ska vara rimligt separerade.

---

## 6. Domänmodell

### 6.1 Mötesrum

Ett mötesrum ska minst innehålla:

- ID
- namn
- kapacitet
- aktiv eller inaktiv status

Rumsnamnet ska vara obligatoriskt och unikt.

Inaktiva rum får visas i befintliga bokningar men ska inte kunna väljas när en ny bokning skapas.

### 6.2 Bokning

En bokning ska minst innehålla:

- ID
- rubrik
- bokarens namn
- mötesrummets ID
- starttid
- sluttid
- status
- tidpunkt då bokningen skapades

Status ska minst kunna ha värdena Aktiv och Avbokad.

Avbokade bokningar ska behållas i databasen men inte blockera nya bokningar.

---

## 7. Blazor-sidor och routning

Applikationen ska minst innehålla följande adresser:

```text
/bookings
/bookings/new
/bookings/{id}
/bookings/{id}/edit
```

Startsidan `/` får visa bokningslistan eller omdirigera till `/bookings`.

Navigering ska använda Blazors navigeringsfunktioner. Applikationen ska inte vara beroende av fullständiga omladdningar för att uppdatera tillstånd.

En direkt navigering till en bokning som inte finns ska visa ett tydligt meddelande. Den får inte visa ett obehandlat undantag eller en tom komponent.

### 7.1 Bokningslista

Bokningslistan ska:

- läsa bokningar asynkront
- visa ett laddningsläge
- visa ett tomt läge när inget matchar
- sortera kommande bokningar efter starttid
- kunna filtrera efter rum och datum
- uppdateras när filtret ändras
- visa fel begripligt om data inte kan hämtas

Varje rad ska visa rubrik, mötesrum, bokare, starttid, sluttid och status.

Avbokade bokningar ska vara visuellt särskiljbara. Status får inte kommuniceras enbart med färg.

### 7.2 Skapa bokning

Formuläret ska innehålla:

- rubrik
- bokarens namn
- mötesrum
- datum
- starttid
- sluttid

Följande regler gäller:

- Rubrik är obligatorisk.
- Bokarens namn är obligatoriskt.
- Ett aktivt mötesrum måste väljas.
- Starttid och sluttid är obligatoriska.
- Sluttiden måste vara senare än starttiden.
- En bokning får inte börja bakåt i tiden.
- En bokning får inte överlappa en annan aktiv bokning i samma rum.

Efter en lyckad bokning ska användaren navigeras till detaljsidan. En omladdning eller ett dubbelt klick får inte skapa en dubblett.

### 7.3 Visa bokning

Detaljsidan ska visa all information om bokningen och erbjuda möjligheter att:

- återgå till bokningslistan
- redigera bokningen
- avboka bokningen

### 7.4 Redigera bokning

Användaren ska kunna ändra rubrik, bokarens namn, mötesrum, starttid och sluttid.

Samma valideringsregler som vid skapande ska användas. Vid kontroll av överlappning får bokningen inte jämföras med sig själv.

En avbokad bokning får inte redigeras.

### 7.5 Avboka bokning

Avbokning ska kräva en uttrycklig bekräftelse. Bokningen ska inte tas bort utan få statusen Avbokad.

Att försöka avboka en redan avbokad bokning ska inte skapa felaktiga data.

---

## 8. Blazor-formulär och komponenttillstånd

Formulär ska använda Blazors formulärkomponenter, exempelvis:

- `EditForm`
- `DataAnnotationsValidator`
- `ValidationSummary`
- `ValidationMessage`

Formulärmodellen ska vara skild från databasmodellen om direkt bindning annars gör det möjligt att ändra skyddade egenskaper.

När ett formulär skickas ska:

- spara-knappen inaktiveras tillfälligt
- ett pågående läge visas
- dubbla klick inte skapa flera operationer
- inmatningen bevaras vid valideringsfel
- valideringsfel visas både i sammanfattning och vid berört fält
- oväntade fel visas begripligt

Komponenterna ska hantera tillstånden laddar, data tillgängliga, inga resultat, valideringsfel, sparar, lyckades, misslyckades och resursen hittades inte.

En `DbContext` får inte leva under hela komponentens livstid. Databaskontexter ska normalt skapas per operation med `IDbContextFactory<RoomBookingDbContext>`.

---

## 9. Affärslogik

Affärsregler ska ligga i ett gemensamt tjänstelager och inte direkt i `.razor`-komponenter eller API-endpoints.

Blazor-komponenterna ska ansvara för presentation, formulärbindning, navigering och visning av status.

Tjänstelagret ska ansvara för:

- validering av tidsintervall
- kontroll av överlappningar
- kontroll av aktiva mötesrum
- skapande och uppdatering av bokningar
- avbokning
- hantering av samtidiga bokningsförsök

Det ska gå att testa affärsreglerna utan att starta en webbläsare eller webbserver.

### 9.1 Överlappande bokningar

Två aktiva bokningar i samma rum får inte överlappa varandra.

Följande intervall överlappar:

```text
Bokning A: 10:00–11:00
Bokning B: 10:30–11:30
```

Följande är tillåtet:

```text
Bokning A: 10:00–11:00
Bokning B: 11:00–12:00
```

Överlappningsregeln ska motsvara:

```text
ny starttid < befintlig sluttid
och
ny sluttid > befintlig starttid
```

Kontrollen ska endast omfatta samma rum, aktiva bokningar och andra bokningar än den som redigeras.

### 9.2 Samtidighet

Applikationen ska så långt det är praktiskt möjligt förhindra att två samtidiga anrop skapar överlappande eller dubbla bokningar.

Kontrollen måste ske på serversidan i samband med sparandet. Om en konkurrerande bokning hinner sparas ska användaren eller API-klienten få ett begripligt fel och ingen felaktig bokning ska skapas.

---

## 10. Web API för externa klienter

RoomBooking ska innehålla ett HTTP-baserat Web API för externa klienter, exempelvis en mobilapp.

Blazor-gränssnittet och API:t ska använda samma databas, domänmodeller, affärsregler, validering och tjänstelager.

```text
Blazor-komponent ─┐
                  ├── Bokningstjänst ── Databas
Web API ──────────┘
```

Affärslogik får inte dupliceras mellan gränssnittet och API:t.

API:t får implementeras med Minimal APIs eller API-controllers. Det ska använda asynkrona operationer och separata DTO-klasser. Entity Framework-entiteter får inte exponeras direkt som API-kontrakt.

### 10.1 Grundadresser

```text
/api/rooms
/api/bookings
```

### 10.2 Hämta mötesrum

```http
GET /api/rooms
GET /api/rooms?activeOnly=true
```

Svaret ska innehålla ID, namn, kapacitet och aktiv status.

### 10.3 Hämta bokningar

```http
GET /api/bookings
GET /api/bookings?roomId=2&date=2026-10-15&status=active
```

API:t ska stödja filtrering med `roomId`, `date` och `status`. Resultatet ska sorteras efter starttid.

Om inget matchar ska `200 OK` med en tom JSON-array returneras.

### 10.4 Hämta en bokning

```http
GET /api/bookings/{id}
```

- `200 OK` om bokningen finns
- `404 Not Found` om den inte finns

### 10.5 Skapa en bokning

```http
POST /api/bookings
```

Exempel:

```json
{
  "title": "Projektmöte",
  "bookedBy": "Anna Andersson",
  "roomId": 2,
  "startTime": "2026-10-15T10:00:00+02:00",
  "endTime": "2026-10-15T11:00:00+02:00"
}
```

Vid framgång ska API:t returnera `201 Created`, den skapade bokningen och en `Location`-header till `/api/bookings/{id}`.

Möjliga fel:

- `400 Bad Request` vid ogiltiga eller saknade värden
- `404 Not Found` om mötesrummet inte finns
- `409 Conflict` om rummet är inaktivt eller tiden kolliderar

### 10.6 Uppdatera en bokning

```http
PUT /api/bookings/{id}
```

Möjliga resultat:

- `200 OK` med uppdaterad bokning
- `400 Bad Request` vid ogiltiga värden
- `404 Not Found` om bokningen inte finns
- `409 Conflict` vid tidskollision eller otillåten redigering

### 10.7 Avboka en bokning

```http
POST /api/bookings/{id}/cancel
```

Operationen ska vara idempotent. Upprepade anrop får inte skapa felaktiga data eller ytterligare ändringar.

### 10.8 Datum och tid

API:t ska använda ISO 8601. Tidpunkter ska representeras med `DateTimeOffset` eller en annan lösning som uttryckligen bevarar tidszon eller UTC-offset.

API:t får inte vara beroende av serverns språkinställningar för att tolka datum.

### 10.9 Felmodell

API-fel ska returneras som `ProblemDetails` eller `ValidationProblemDetails` med konsekvent struktur.

Interna undantag, stack traces, databasdetaljer och känsliga tekniska uppgifter får inte skickas till klienten.

### 10.10 OpenAPI och CORS

API:t ska publicera en OpenAPI-beskrivning i utvecklings- och testmiljö.

Tillåtna CORS-origins ska komma från konfiguration. En generell wildcard-origin ska inte vara standard i produktionsmiljö.

---

## 11. Validering, säkerhet och felhantering

All viktig validering ska utföras på serversidan. Klientbaserad validering är endast ett komplement.

Applikationen ska hantera:

- obligatoriska fält som saknas
- sluttid som är före eller lika med starttid
- bokningar bakåt i tiden
- mötesrum som inte finns
- inaktiva mötesrum
- överlappande bokningar
- bokningar som inte finns
- ID:n med ogiltigt format
- databasfel vid sparande

Minimikrav för säkerhet:

- formulär som ändrar data ska skyddas mot CSRF där det är tillämpligt
- användarinmatning får inte skrivas ut som osäker HTML
- databasfrågor ska använda parametriserade mekanismer
- interna undantag får inte visas för användaren
- indata ska valideras på serversidan
- skyddade och serverstyrda egenskaper får inte kunna ändras genom extra fält
- API-kontrakt får inte exponera interna databasfält

---

## 12. Tillgänglighet och användbarhet

Blazor-komponenterna ska generera semantiskt korrekt HTML.

Följande krav gäller:

- formulärfält ska ha synliga och korrekt kopplade etiketter
- valideringsfel ska vara begripliga och ligga nära berörda fält
- en valideringssammanfattning ska visas
- felmeddelanden ska kunna uppfattas av hjälpmedel
- tangentbordsfokus ska vara synligt
- rubrikstrukturen ska vara logisk
- dialogliknande bekräftelser ska fungera med tangentbord
- laddningsstatus ska inte kommuniceras enbart med animation
- status får inte kommuniceras enbart med färg
- knappar och länkar ska användas enligt sin avsedda funktion

Egen JavaScript-kod ska undvikas när funktionen rimligen kan implementeras med Blazor. Nödvändig JavaScript-interoperabilitet ska vara begränsad och dokumenterad.

---

## 13. Startdata

Utvecklings- och testmiljön ska kunna fyllas med minst:

- Alfa, kapacitet 4
- Beta, kapacitet 8
- Gamma, kapacitet 12

Minst ett rum ska kunna markeras som inaktivt. Det ska även finnas exempelbokningar.

Startdata får inte dupliceras när applikationen startas flera gånger.

---

## 14. Automatisk framställning av felversioner

Felversionen får skapas av en separat språkmodell efter att referensapplikationen har färdigställts och verifierats.

Modellen som skapar felen benämns **buggmodellen**. Modellen som diagnostiserar och rättar dem benämns **fixmodellen**.

Arbetsflödet ska vara:

1. Byggmodellen färdigställer Blazor-applikationen och API:t.
2. Samtliga tester körs.
3. En godkänd referens-commit skapas och fryses.
4. Buggmodellen inför två eller tre realistiska fel i exakt denna version.
5. En automatisk kontroll verifierar att projektet fortfarande bygger och att buggspecifika tester misslyckas.
6. Fixmodellen får den felaktiga versionen och buggrapporterna.
7. Resultatet bedöms med dolda tester mot den frysta referensversionen.

Samma felaktiga version ska användas för alla fixmodeller som jämförs.

Buggmodellen och fixmodellen bör inte vara samma modellfamilj om detta kan undvikas.

### 14.1 Buggmodellens leverans

För varje fel ska buggmodellen leverera:

- en kodändring
- en användarinriktad buggrapport
- steg för att reproducera felet
- förväntat och faktiskt resultat
- ett privat facit med teknisk grundorsak
- ett förslag på dolt test som avslöjar felet
- en referenskorrigering eller återställningsinstruktion

Buggrapporten får inte avslöja grundorsak, filnamn, metodnamn, kodrad eller färdig lösning.

Buggmodellen får inte ändra eller ta bort befintliga tester.

### 14.2 Lagring av fel

Varje fel bör lagras som en separat patch eller commit:

```text
bugs/
├── RB-201/
│   ├── bug.patch
│   ├── report.md
│   ├── private-manifest.json
│   └── hidden-tests/
├── RB-202/
└── RB-203/
```

Det ska vara möjligt att aktivera varje fel separat, kombinera fel och återställa den korrekta versionen.

### 14.3 Godkännande av ett infört fel

Innan en felversion används ska systemet verifiera att:

1. referensversionen bygger och klarar alla tester
2. felversionen fortfarande kompilerar och kan startas
3. varje fel kan reproduceras
4. minst ett specifikt test misslyckas för varje fel
5. orelaterad funktionalitet fortfarande fungerar
6. referenskorrigeringen får alla tester att passera
7. buggrapporten beskriver symptomen utan att avslöja lösningen

Fel som gör att projektet inte bygger ska endast användas i en särskild kategori för kompileringsfel.

---

## 15. Exempel på fel och buggrapporter

Feluppsättningarna kan innehålla både generell affärslogik, Blazor-fel och API-fel.

### 15.1 Affärslogik

- Angränsande bokningar nekas på grund av fel jämförelseoperator.
- En bokning kolliderar med sig själv vid redigering.
- Datumfiltret missar bokningar senare under dagen.
- Avbokade bokningar blockerar nya bokningar.
- Ett inaktivt rum kan bokas.

### 15.2 Blazor

- Bokningslistan uppdateras inte när filtret ändras.
- En asynkron händelsehanterare inväntas inte.
- Dubbla klick skapar två bokningar.
- Formulärmodellen återställs efter ett valideringsfel.
- En parameterändring hanteras bara i `OnInitializedAsync`.
- Redigeringssidan visar data från föregående ruttparameter.
- Felaktig användning av `@key` blandar ihop formulärvärden.
- En knapp saknar korrekt typ och skickar formuläret oavsiktligt.
- En komponent använder samma `DbContext` under hela sin livstid.

### 15.3 Web API

- En endpoint returnerar `200 OK` i stället för `404 Not Found`.
- Skapande saknar `Location` eller returnerar fel statuskod.
- API:t använder inte samma överlappningskontroll som Blazor.
- Ogiltiga värden ger `500 Internal Server Error`.
- `PUT` skriver över serverstyrda egenskaper.
- Avbokning är inte idempotent.
- API:t exponerar oönskade Entity Framework-fält.
- Två snabba `POST`-anrop skapar dubbletter.
- CORS blockerar en uttryckligt tillåten extern klient.

### 15.4 Exempel: angränsande bokningar

**Buggrapport RB-101: Angränsande bokningar nekas**

**Steg:**

1. Skapa en bokning i rum Alfa mellan 10:00 och 11:00.
2. Försök skapa en ny bokning i samma rum mellan 11:00 och 12:00.

**Förväntat:** Den nya bokningen skapas.

**Faktiskt:** Formuläret anger att rummet redan är bokat.

### 15.5 Exempel: Blazor-listan uppdateras inte

**Buggrapport RB-201: Datumfiltret uppdaterar inte listan**

**Steg:**

1. Öppna bokningslistan.
2. Välj ett datum som innehåller bokningar.
3. Byt till ett datum utan bokningar.

**Förväntat:** Listan visar att det inte finns några bokningar.

**Faktiskt:** Föregående bokningar ligger kvar tills sidan laddas om.

### 15.6 Exempel: API-statuskod

**Buggrapport RB-301: Saknad bokning ser ut att lyckas**

**Steg:**

1. Skicka `GET /api/bookings/999999`.

**Förväntat:** API:t returnerar `404 Not Found` med `ProblemDetails`.

**Faktiskt:** API:t returnerar `200 OK` med ett tomt svar.

---

## 16. Testning

### 16.1 Enhetstester

Enhetstester ska minst kontrollera att:

- överlappande bokningar nekas
- angränsande bokningar tillåts
- en bokning inte kolliderar med sig själv vid redigering
- avbokade bokningar inte blockerar tider
- inaktiva rum inte kan bokas
- felaktiga tidsintervall nekas

### 16.2 Komponenttester

bUnit kan användas för att kontrollera att:

- laddningsläge visas
- bokningslistan renderas korrekt
- tomt läge visas
- valideringsmeddelanden visas
- knappar inaktiveras under sparande
- rätt navigering sker efter en lyckad operation
- felmeddelanden visas när tjänsten returnerar fel

### 16.3 API-tester

API-tester ska minst verifiera att:

- mötesrum kan hämtas
- bokningslistan kan filtreras
- en bokning kan hämtas
- en giltig bokning kan skapas
- skapande ger `201 Created` och `Location`
- en bokning kan uppdateras
- en bokning kan avbokas
- överlappning ger `409 Conflict`
- angränsande bokningar tillåts
- ogiltiga värden ger `400 Bad Request`
- saknade resurser ger `404 Not Found`
- fel returneras i dokumenterad struktur
- API:t och Blazor följer samma regler
- interna egenskaper inte exponeras

### 16.4 Webbläsartester

Playwright ska testa följande användarflöde:

1. öppna bokningslistan
2. skapa en bokning
3. kontrollera att bokningen visas
4. redigera bokningen
5. filtrera fram bokningen
6. avboka bokningen
7. kontrollera att tiden kan bokas igen

Testerna ska även kontrollera tangentbordsnavigering, valideringsfel, dubbla klick och navigering till ett ID som inte finns.

---

## 17. Regler för modellerna

Modellerna får:

- läsa hela projektets produktionskod
- bygga och köra applikationen
- köra synliga tester
- skapa och ändra produktionskod
- lägga till egna tester
- använda bygg- och testresultat i felsökningen

Modellerna får inte:

- ändra eller ta bort benchmarkens tester
- läsa dolda tester eller facit
- hårdkoda testresultat
- inaktivera validering för att få tester att passera
- ersätta applikationen med statiska sidor
- ansluta till externa tjänster som inte anges
- ändra testdata för att dölja ett fel

En alternativ implementation ska godkännas om den uppfyller beteendekraven och testerna, även om den skiljer sig från referenslösningen.

---

## 18. Bedömning

Resultat för implementationsläget och felrättningsläget ska redovisas separat. Dessutom ska delpoäng för Blazor, affärslogik och API redovisas.

### 18.1 Läge A: slutför applikationen

| Område | Maxpoäng |
|---|---:|
| Lösningen kompilerar och startar | 10 |
| Blazor-sidor och grundflöden | 15 |
| Formulär och komponenttillstånd | 10 |
| Affärsregler och validering | 20 |
| Web API | 20 |
| Dolda gränsfall och samtidighet | 10 |
| Tillgänglighet | 5 |
| Tester, kodkvalitet och struktur | 10 |
| **Totalt** | **100** |

### 18.2 Läge B: rätta fel

| Område | Maxpoäng |
|---|---:|
| Lösningen kompilerar och startar | 10 |
| Rapporterat fel 1 är rättat | 20 |
| Rapporterat fel 2 är rättat | 20 |
| Rapporterat fel 3 är rättat | 20 |
| Befintliga regressionstester passerar | 15 |
| Relevanta gränsfall hanteras | 5 |
| Ändringen är begränsad och underhållbar | 5 |
| Nya relevanta regressionstester | 5 |
| **Totalt** | **100** |

Om en variant endast innehåller två fel ska felpoängen fördelas om.

En buggrapport räknas som löst när det buggspecifika dolda testet, relevanta gränsfall och den ordinarie regressionstestsviten passerar.

---

## 19. Resultat som ska registreras

För varje körning ska följande sparas:

- benchmarkläge och variant
- start-commit
- modell och exakt modellversion
- datum och tid
- systeminstruktion och uppgiftsprompt
- tillåtna verktyg
- maximal körtid
- antal modellinteraktioner
- in- och utgående tokens
- uppskattad kostnad
- total körtid
- antal bygg- och testförsök
- antal ändrade filer
- tillagda och borttagna kodrader
- byggresultat
- resultat per testkategori
- vilka buggrapporter som löstes
- antal regressioner
- delpoäng för Blazor, API och affärslogik
- slutpoäng
- modellens slutliga kodändring
- modellens sammanfattning

---

## 20. Reproducerbarhet och isolering

Varje körning ska starta från samma versionshanterade commit och utföras i en ren, isolerad miljö.

Följande ska versionshanteras:

- startprojekt
- kravspecifikation
- buggrapporter
- synliga och dolda tester
- testdata
- .NET-version
- beroenden
- modellinställningar
- bedömningslogik
- facit för införda fel

Genererad kod ska byggas och köras i en container eller annan begränsad miljö. Den ska inte köras direkt på en dator med känsliga filer eller autentiseringsuppgifter.

Temperatur och övriga modellparametrar ska vara identiska mellan jämförbara körningar. Stokastiska modeller bör köras flera gånger och redovisas med genomsnitt, median och variation.

---

## 21. Benchmarkvarianter

För att minska risken för memorering ska flera likvärdiga varianter kunna skapas, exempelvis:

- andra namn på modeller och egenskaper
- bokning av utrustning i stället för mötesrum
- andra tidsintervall och testdata
- olika kombinationer av två eller tre fel
- samma symptom med olika tekniska orsaker
- olika Blazor- och API-fel

Feluppsättningarna bör roteras. Varianterna ska pröva jämförbara förmågor och använda samma poängmodell.

---

## 22. Avgränsningar

Följande ingår inte i benchmarkens första version:

- användarkonton och inloggning
- e-postutskick
- kalenderintegration
- betalningar
- flerspråkighet
- avancerad grafisk design
- molndistribution
- administration av användare och roller

---

## 23. Målsättning

En modell som klarar benchmarken väl ska inte bara kunna producera syntaktiskt korrekt C#-kod.

I implementationsläget ska den kunna förstå och färdigställa en mindre men realistisk Blazor-applikation med gemensam affärslogik och ett externt Web API.

I felrättningsläget ska den kunna förstå buggrapporter, lokalisera grundorsaker, genomföra begränsade korrigeringar och undvika regressioner.

De viktigaste slutmåtten är:

- andelen uppfyllda krav
- andelen godkända tester
- andelen korrekt lösta buggrapporter
- antal regressioner
- kostnad och tidsåtgång
- hur ofta modellen lyckas på första försöket
- kvaliteten i Blazor-gränssnittet, API:t och den gemensamma affärslogiken

