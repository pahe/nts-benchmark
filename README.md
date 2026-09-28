# nts-benchmark

RoomBooking-benchmark för kodande språkmodeller.

## Standardkörning

Standardkonfigurationen finns i `config/defaults.json`. En ny implementationsomgång skapas och startas från PowerShell:

```powershell
$id = [Guid]::NewGuid()
./scripts/New-BenchmarkRun.ps1 -Id $id
./scripts/Start-Implementation.ps1 -Id $id
```

Det andra kommandot använder som standard `gpt-6-sol` med reasoning-nivån `medium`. Körningens prompt, händelsespår, slutmeddelande, kod och testresultat sparas under `runs/{GUID}/implementation/`.

Ett GUID får inte återanvändas. Skripten avbryter om omgången eller implementationsfasen redan finns.

Se `docs/benchmark-korningar.md` för den fullständiga körningsmodellen.
