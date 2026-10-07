# adapters/primary-source/congress/

api.congress.gov adapter — fetch bills, public laws, amendments.

**API:** https://api.congress.gov/v3/
**Auth:** `CONGRESS_API_KEY` env var required (free 5,000 req/hr at https://api.congress.gov/sign-up/)

## Usage

```powershell
# Public law
pwsh fetch.ps1 -PublicLaw "117-103" -CachePath .\cache

# Specific bill
pwsh fetch.ps1 -Congress 117 -BillType hr -BillNumber 3076 -CachePath .\cache

# Senate bill, joint resolution, etc.
pwsh fetch.ps1 -Congress 117 -BillType s -BillNumber 1605 -CachePath .\cache
pwsh fetch.ps1 -Congress 118 -BillType hjres -BillNumber 1 -CachePath .\cache
```

## Bill types

`hr` (House bill), `s` (Senate bill), `hjres` (House joint resolution), `sjres` (Senate joint resolution), `hconres` (House concurrent resolution), `sconres` (Senate concurrent resolution), `hres` (House simple resolution), `sres` (Senate simple resolution).

## Operator setup

```powershell
[Environment]::SetEnvironmentVariable('CONGRESS_API_KEY', '<key>', 'User')
# Restart shell; verify:
[Environment]::GetEnvironmentVariable('CONGRESS_API_KEY', 'User').Length  # should be 32+
```

## See `../ADAPTERS-README.md` for the full envelope + architecture.
