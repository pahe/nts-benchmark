RoomBooking är implementerat i [RoomBooking.sln]([workspace]/runs/006fd21f-1225-447a-9301-0e5ccde8cf82/implementation/workspace/RoomBooking.sln). Lösningen innehåller ett interaktivt Blazor-gränssnitt, HTTP-API, gemensamt tjänstelager, Entity Framework Core och SQLite. [README.md]([workspace]/runs/006fd21f-1225-447a-9301-0e5ccde8cf82/implementation/workspace/README.md) beskriver start och API.

`dotnet build RoomBooking.sln --no-restore` lyckades. `dotnet test RoomBooking.sln --no-restore` passerade: **9 av 9 tester**, inklusive tjänste-, API-, bUnit- och Chromium-test.

Kvarstående begränsning: paketåterställningen varnar för kända sårbarheter i de tillgängliga versionerna av SQLitePCLRaw och AngleSharp. Kontroll mot paketkällans sårbarhetsdata kunde inte slutföras i miljön.