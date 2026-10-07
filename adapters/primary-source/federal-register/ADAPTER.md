# adapters/primary-source/federal-register/

Federal Register adapter — fetch FR notices, rulemakings, executive orders.

**API:** https://www.federalregister.gov/api/v1/ (no auth)
**Endpoints:** `/documents/{document_number}.json` or `/documents.json?conditions[volume]=&conditions[page]=` or `/documents.json?conditions[docket_id]=`

## Usage

```powershell
pwsh fetch.ps1 -Cite "85 FR 12345" -CachePath .\cache
pwsh fetch.ps1 -DocumentNumber "2020-12345" -CachePath .\cache
pwsh fetch.ps1 -DocketId "SEC-2020-001" -CachePath .\cache
```

## What's fetched

Document JSON metadata: title, citation, abstract, dates, agencies, action codes, dates_signed, effective_date, document_number, full_text_xml_url (link to body XML — not yet auto-pulled).

## See `../ADAPTERS-README.md` for the full envelope + architecture.
