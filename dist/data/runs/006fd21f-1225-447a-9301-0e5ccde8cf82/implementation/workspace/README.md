# RoomBooking

RoomBooking är en Blazor Web App (.NET 10, Interactive Server) med ett HTTP-API. Båda använder samma bokningstjänst och en lokal SQLite-databas.

## Starta

```text
dotnet build RoomBooking.sln
dotnet run --project RoomBooking.Web
```

Öppna `/bookings`. Databasen `roombooking.db` skapas automatiskt med rummen Alfa, Beta och Gamma samt en exempelbokning. Gamma är inaktivt. Anslutningen kan ändras med `ConnectionStrings__RoomBooking`.

Formuläret visar och skickar tider i UTC. API:t tar emot ISO 8601 med offset och returnerar tider normaliserade till UTC. Datumfiltret avser UTC-dygn.

## API

- `GET /api/rooms?activeOnly=true`
- `GET /api/bookings?roomId=1&date=2026-10-15&status=active`
- `GET /api/bookings/{id}`
- `POST /api/bookings`
- `PUT /api/bookings/{id}`
- `POST /api/bookings/{id}/cancel`

Swagger finns på `/swagger` i Development och Test. CORS-origins konfigureras med `Cors:AllowedOrigins`.

## Tester

```text
dotnet test RoomBooking.sln
```

Sviten innehåller tester för tjänst, API, bUnit-komponenter och ett Chromium-flöde med Playwright. Chromium måste vara installerat för webbläsartestet.
