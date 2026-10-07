# adapters/primary-source/ — Primary-Source API Adapters

**Framework version:** v3.1.13+
**Purpose:** Automate primary-source fetching and amendment detection for U.S. legal Topic KBs.

## What this is

Four adapters that fetch authoritative U.S. legal primary sources via official government APIs:

| Adapter | Source | Auth | Use for |
|---|---|---|---|
| `ecfr/` | https://www.ecfr.gov/api/versioner/v1/ | None | Code of Federal Regulations (current + historical) |
| `congress/` | https://api.congress.gov/v3/ | Free API key | Bills, public laws, amendments |
| `federal-register/` | https://www.federalregister.gov/api/v1/ | None | Federal Register notices, rulemakings |
| `govinfo/` | https://api.govinfo.gov/ | Free API key | USCODE, PLAW, FR, BILLS, STATUTE, CFR packages |

Each adapter ships a Python script (`fetch.py`) + PowerShell wrapper (`fetch.ps1`).

## Architecture

- **Python sidecar pattern**: PowerShell wrapper invokes Python script via `Get-Command python`. Python emits a single JSON envelope to stdout; PowerShell parses, formats, and exits with adapter exit code.
- **Stdlib-only Python**: no `pip install` required. Uses `urllib.request`, `json`, `hashlib`, `pathlib`.
- **Content-addressed cache**: each fetch writes `<cache>/<adapter>/<slug>.<ext>` + `<slug>.manifest.json`. SHA256 is computed on response body.
- **Diff detection**: second fetch compares against prior manifest's `sha256`. Sets `diff_status: new | unchanged | changed`.
- **Graceful degradation**: missing Python → exits 4 with `python_missing`. Missing API key → exits 5 with `missing_api_key`. HTTP errors classified into `auth_failure | source_not_found | rate_limit | upstream_error | fetch_error` with actionable `remediation` strings.

## Output envelope (all adapters)

```json
{
  "status": "success",
  "adapter": "ecfr",
  "identifier": "17 CFR 240.10b-5",
  "source_url": "https://www.ecfr.gov/api/versioner/v1/full/2025-01-01/title-17.xml?part=240&section=240.10b-5",
  "sha256": "ef1ad818389b...",
  "prior_sha256": null,
  "size": 1169,
  "diff_status": "new",
  "cache_path": ".../cache/ecfr/17-cfr-240-10b-5.2025-01-01.xml",
  "manifest_path": ".../cache/ecfr/17-cfr-240-10b-5.2025-01-01.manifest.json",
  "citation": "17 CFR 240.10b-5 (eCFR as of 2025-01-01)",
  "fetched_at": "2026-06-08T..."
}
```

On error:
```json
{
  "status": "error",
  "adapter": "congress",
  "error_type": "missing_api_key",
  "error_message": "CONGRESS_API_KEY env var is not set.",
  "remediation": "Get a free key at https://api.congress.gov/sign-up/ and set with: [Environment]::SetEnvironmentVariable('CONGRESS_API_KEY', '<key>', 'User')"
}
```

## Operator setup

### Required (always)
- Python 3.12 or later on PATH. Already installed by `~/.copilot/bootstrap.ps1`.

### Optional (per-adapter, only if you use that adapter)
- **Congress**: set `CONGRESS_API_KEY` env var. Free at https://api.congress.gov/sign-up/ (5,000 req/hr).
- **GovInfo**: set `GOVINFO_API_KEY` env var. Free at https://api.govinfo.gov/docs/.

```powershell
# One-time setup at User scope
[Environment]::SetEnvironmentVariable('CONGRESS_API_KEY', '<key>', 'User')
[Environment]::SetEnvironmentVariable('GOVINFO_API_KEY', '<key>', 'User')
```

eCFR and Federal Register require no key.

## Integration into the framework pipeline

The 22-phase pipeline integrates these adapters at two points:

### Phase 1.1 (Builder Research) — pre-fetch
When `sources/source-registry.yaml` exists with `auto_fetch_on_phase_1_1: true`, the orchestrator dispatches the relevant adapter for each registered source before invoking Builder A + Builder B. Builders read from `external/primary-sources/cache/` rather than relying on the LLM's training-data recall.

### Phase 6.3 (Extraction) — drift detection
When `drift_report_on_phase_6_3: true`, the orchestrator re-fetches all registered sources and writes `sources/source_drift_report.md` listing any sources whose `sha256` changed since the Phase 1.1 fetch. Foundational-criticality changes BLOCK the build pending operator review (the KB content was drafted against an older version of the source).

Both integrations are declared in `audit-templates/phase-contracts.yaml`.

## Schema validation

`source-registry.yaml` is validated against `audit-templates/source-registry.schema.json` using `Test-Json -SchemaFile`. The pattern matches v3.1.11's pipeline-state.yaml + v3.1.12's phase-contracts.yaml.

## Standalone usage (without the framework)

Each adapter works as a standalone CLI:

```powershell
# eCFR (no key)
pwsh adapters/primary-source/ecfr/fetch.ps1 -CiteString "17 CFR 240.10b-5" -CachePath .\cache

# Federal Register (no key)
pwsh adapters/primary-source/federal-register/fetch.ps1 -DocumentNumber "2020-12345" -CachePath .\cache
pwsh adapters/primary-source/federal-register/fetch.ps1 -Cite "85 FR 12345" -CachePath .\cache
pwsh adapters/primary-source/federal-register/fetch.ps1 -DocketId "SEC-2020-001" -CachePath .\cache

# Congress (requires CONGRESS_API_KEY)
pwsh adapters/primary-source/congress/fetch.ps1 -PublicLaw "117-103" -CachePath .\cache
pwsh adapters/primary-source/congress/fetch.ps1 -Congress 117 -BillType hr -BillNumber 3076 -CachePath .\cache

# GovInfo (requires GOVINFO_API_KEY)
pwsh adapters/primary-source/govinfo/fetch.ps1 -Collection PLAW -Congress 117 -LawNumber 103 -CachePath .\cache
pwsh adapters/primary-source/govinfo/fetch.ps1 -Collection USCODE -Year 2024 -Title 15 -CachePath .\cache
```

Add `-Json` to any wrapper to emit raw Python JSON output instead of formatted text.

## Limitations and known issues

- **eCFR fallback to latest-available-date**: if today's date isn't yet indexed (eCFR typically lags by 1-3 days), the adapter auto-queries the titles endpoint and retries with the most recent indexed date. Logged in `manifest.json` as `as_of: <fallback-date>`.
- **No content-only diff yet**: `diff_status: changed` indicates SHA mismatch but doesn't show a textual diff. Future enhancement (v3.1.x) could write a unified-diff summary into `source_drift_report.md`.
- **Federal Register full-text not yet fetched**: the document JSON includes `full_text_xml_url` but the adapter doesn't currently pull the full XML. Future enhancement.
- **GovInfo summary endpoint only**: pulls package summary metadata. To pull the package's body content, follow `downloadUrl` fields in the summary JSON. Future enhancement.
- **Non-US jurisdictions not yet supported**: EU regulatory KBs (CRA, NIS2, AI Act, MDR, GDPR, DMA/DSA, etc.) need an EUR-Lex SPARQL adapter. Future patch.

## See also

- `audit-templates/source-registry.schema.json` — JSON Schema for source-registry.yaml
- `examples/source-registry.example.yaml` — Golden reference
- `audit-templates/phase-contracts.yaml` — Phase 1.1 and 6.3 integration declarations
- `CHANGELOG.md` [3.1.13] entry
