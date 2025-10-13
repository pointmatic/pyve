# Technical Design: Google Sheets → Google Docs Data Merge

## Overview
A CLI tool automates document generation by merging rows from a Google Sheet into copies of a Google Docs template. Placeholders in the template like `{_placeholder_name_}` are replaced with values from matching column names in the sheet.

## Languages and Stack
- Language: Python 3.11+
- Libraries:
  - google-api-python-client (Docs, Drive, Sheets)
  - google-auth, google-auth-oauthlib, google-auth-httplib2
  - gspread (optional convenience for Sheets reads)
  - python-dotenv (config)
- Execution: CLI (invoked locally or in CI)

## Google Resources
- Data sheet: a Google Sheets document with a header row. Each subsequent row represents a merge record.
- Template doc: a Google Docs document with placeholders `{_Column_Header_Name_}`.

## Authentication
- OAuth client credentials JSON for installed app flow (local development) with offline access token stored locally.
- Service Account alternative for headless execution; requires Doc and Sheet sharing to the service account.
- Scopes:
  - https://www.googleapis.com/auth/documents
  - https://www.googleapis.com/auth/drive
  - https://www.googleapis.com/auth/spreadsheets.readonly

## Configuration
- `.env` or CLI flags:
  - SHEET_ID
  - TEMPLATE_DOC_ID
  - OUTPUT_FOLDER_ID (Drive folder to store generated docs)
  - ROW_FILTER (optional A1 notation or query to limit rows)
  - DRY_RUN (boolean)

## Placeholder Convention
- Template placeholders use `{_placeholder_name_}`.
- Matching is case-insensitive on header names after trimming and replacing spaces with underscores.
- Missing values default to empty string unless `--strict` is set (then fail the row with an error).

## Merge Algorithm
1. Resolve configuration and authenticate.
2. Read header row and data rows from the Sheet.
3. For each row:
   - Build a mapping: `header -> cell_value`.
   - Compute replacements for all placeholders present in the template.
   - Duplicate the template in Drive to a new Doc. Name pattern: `<TemplateName> - <PrimaryKey or RowIndex>`.
   - Use Docs API `batchUpdate` with `replaceAllText` requests for each placeholder.
   - Move the new Doc to `OUTPUT_FOLDER_ID` (if provided).
4. Emit a run summary (success/fail counts, links to created Docs).

## Error Handling & Resilience
- Validate that required IDs are accessible before processing.
- Row-level errors do not stop the run; collect and report them.
- Exponential backoff for 429/5xx responses.
- Idempotency key per row (optional) to prevent duplicates if re-running.

## Performance
- Batch read all rows from Sheets in one call.
- Group `replaceAllText` operations per document into a single `batchUpdate` call.
- Parallelize per-row document creation with a small worker pool (configurable), respecting QPS limits.

## Logging & Observability
- Structured logs to stdout.
- Optional CSV/JSON report file with row index, status, and new Doc URL.

## Security
- Never commit credentials; read from environment/secret store.
- Limit OAuth scopes to only what’s required.
- Principle of least privilege on Drive folder sharing.

## CLI Sketch
```
merge-docs \
  --sheet-id <SHEET_ID> \
  --template-id <TEMPLATE_DOC_ID> \
  --output-folder-id <FOLDER_ID> \
  [--row-filter "A2:Z"] \
  [--strict] \
  [--dry-run]
```

## Next Steps
- Scaffold Python project with entrypoint `merge_docs/cli.py`.
- Implement auth helpers and clients for Sheets, Docs, Drive.
- Implement placeholder extraction and normalization.
- Add tests for placeholder mapping and Docs API requests.
- Provide example template and sample sheet in `examples/`.
