# Resultatwebb

Den statiska webbplatsen i `site/` visar benchmarkkörningar sida vid sida. Varje panel har en körningsväljare, en sammanfattning, ett utfällbart manifest, ett filtrerat filträd och en filvisare med radnummer och syntaxmarkering för bland annat C# och JSON.

C#-filer visas som standard med en läsbar visningsformatering som delar upp komprimerade satser och block över flera rader. `Formaterad vy` kan stängas av för att visa exakt originaltext. Formateringen sker endast i webbläsaren och ändrar aldrig run-artefakten eller den kod som bedömdes.

Körningens övre informationsdel är en infällbar accordion. Den kompakta raden visar modell, reasoning effort och körningsstatus. GUID visas inte i det vanliga gränssnittet; det finns kvar i manifestet för spårbarhet.

Filträden visar unionen av båda körningarnas filsökvägar. En fil som bara finns i den aktuella körningen märks `Endast här`; motsvarande plats i den andra körningen märks `Saknas`. Ett filval öppnar samma sökväg i båda panelerna så att tillagda och borttagna filer syns utan att användaren behöver leta manuellt.

När filen finns i båda körningarna gör webbläsaren en radbaserad diff och justerar raderna mot varandra. `+` betyder tillagd rad på höger sida, `−` betyder att vänsterraden saknas på höger sida och `~` betyder att raden ändrats. Markörerna kompletterar bakgrundsfärgerna så att skillnaderna inte kommuniceras enbart med färg. Radhöjder synkroniseras även när långa rader bryts, och valet mellan formaterad C#-vy och original synkroniseras mellan panelerna. För mycket stora filer används en enklare positionsbaserad jämförelse för att undvika att webbläsaren låser sig.

Panelen `Alla resultatmått` följer de 22 punkterna i benchmarkspecifikationens avsnitt 19. Varje punkt märks `Registrerat`, `Delvis registrerat`, `Saknas` eller `Inte tillämpligt`. Historiska körningar kompletteras inte med påhittade värden: generatorn härleder sådant som säkert kan beräknas från artefakterna och visar resten som saknat.

## Uppdatera data

Kör efter att en benchmarkkörning har skapats eller ändrats:

```powershell
./scripts/Build-ResultsSite.ps1
```

Skriptet läser GUID-mapparna i `runs/` och skapar ett publicerbart textunderlag i `site/data/`. Byggartefakter och binära filer publiceras inte. Följande mappar hoppas över: `bin`, `obj`, `.git`, `.vs` och `node_modules`. Filer större än 5 MB hoppas också över.

`site/data/` är en genererad ögonblicksbild. Kör generatorn igen när nya resultat ska visas.

## Kör lokalt

Webbläsare tillåter normalt inte att sidan läser JSON-filer direkt från `file://`. Starta därför den lokala servern:

```powershell
./scripts/Serve-ResultsSite.ps1
```

Öppna därefter `http://127.0.0.1:4173`. Servern bygger om resultatdatan före start. Använd `-SkipBuild` om befintlig data ska visas utan ombyggnad.

Den lokala servern aktiverar knappen `Öppna externt` för den valda filen på respektive sida. Filen öppnas med operativsystemets standardprogram för filtypen. Servern accepterar bara filer som ligger under det valda run-ID:t och tillhör resultatwebbens tillåtna textformat. Funktionen är av säkerhetsskäl inte tillgänglig på GitHub Pages.

## GitHub Pages

Webbplatsen har inga serverberoenden och använder relativa adresser. Skapa alltid den offentliga versionen med:

```powershell
./scripts/Build-PublicResultsSite.ps1
```

Kommandot skapar en separat, publicerbar webbplats i `dist/`. GitHub Pages ska publicera `dist/`, aldrig den lokala `site/data/` direkt.

Den offentliga profilen tar med manifest, run-metadata, prompter, slutsvar och publicerbar källkod. Händelsespår, exakta kommandon, standard error, bygg- och testloggar, TRX-filer samt privat buggförberedelse utelämnas. Lokala arbetsyte- och användarprofilsökvägar ersätts med neutrala platshållare.

Bygget avbryts om den färdiga exporten fortfarande innehåller absoluta användarsökvägar, interna Azure Artifacts-adresser eller vanliga token- och API-nyckelmönster. `dist/data/publication.json` beskriver vad exportprofilen inkluderade och uteslöt.

Prompter, slutsvar och källkod kan fortfarande innehålla verksamhetsinformation som automatiska mönster inte känner igen. Granska därför även `dist/` manuellt före den första offentliga publiceringen.
