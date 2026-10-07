# adapters/primary-source/ecfr/

eCFR adapter — Code of Federal Regulations primary-source fetcher.

**API:** https://www.ecfr.gov/api/versioner/v1/ (no auth)
**Endpoint used:** `/full/{date}/title-{N}.xml?part={P}&section={S}`
**Auto-fallback:** if today's date 404s, queries `/titles.json` for `up_to_date_as_of` and retries.

## Usage

```powershell
pwsh fetch.ps1 -CiteString "17 CFR 240.10b-5" -CachePath .\cache
pwsh fetch.ps1 -CiteString "17 CFR Part 240" -CachePath .\cache -AsOf 2025-01-01
pwsh fetch.ps1 -CiteString "17 CFR" -CachePath .\cache  # entire title
```

## Supported cite formats

- `<title> CFR <part>.<section>` — section, e.g. `17 CFR 240.10b-5`
- `<title> CFR Part <part>` — entire part, e.g. `17 CFR Part 240`
- `<title> CFR <part>` — entire part (ambiguous; treated as part)
- `<title> CFR` — entire title, e.g. `17 CFR`

## See `../ADAPTERS-README.md` for the full envelope + architecture.
