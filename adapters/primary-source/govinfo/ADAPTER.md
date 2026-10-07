# adapters/primary-source/govinfo/

api.govinfo.gov adapter — fetch USCODE, PLAW, FR, BILLS, STATUTE, CFR packages.

**API:** https://api.govinfo.gov/
**Auth:** `GOVINFO_API_KEY` env var required (free at https://api.govinfo.gov/docs/)

## Usage

```powershell
# Public law (structured)
pwsh fetch.ps1 -Collection PLAW -Congress 117 -LawNumber 103 -CachePath .\cache

# Public law (direct package id)
pwsh fetch.ps1 -Collection PLAW -PackageId "PLAW-117publ103" -CachePath .\cache

# U.S. Code title
pwsh fetch.ps1 -Collection USCODE -Year 2024 -Title 15 -CachePath .\cache

# Federal Register issue
pwsh fetch.ps1 -Collection FR -PackageId "FR-2020-12345" -CachePath .\cache
```

## Collections

- `FR` — Federal Register
- `USCODE` — United States Code
- `PLAW` — Public laws
- `BILLS` — Congressional bills
- `STATUTE` — Statutes at Large
- `CFR` — Code of Federal Regulations (use ecfr/ for current-year sections; govinfo for historical CFR volumes)

## Operator setup

```powershell
[Environment]::SetEnvironmentVariable('GOVINFO_API_KEY', '<key>', 'User')
```

## See `../ADAPTERS-README.md` for the full envelope + architecture.
