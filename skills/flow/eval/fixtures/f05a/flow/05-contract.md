# 05 — Contract

## Interfaces

| Method | Path | Request | Response | Errors | Owner |
|---|---|---|---|---|---|
| GET | /healthz | none | `{ "ok": true }` | 503 if deps down | platform |

## Auth

- Public: `/healthz` only.
- All other routes: bearer session token; 401 if missing/invalid.

## Error model

- `code` (string), `message` (string), `request_id` (string).
- 4xx client; 5xx server; no silent 200 on failure.

## Gate
- [x] Every endpoint has method, path, request, response, errors, owner.
- [x] Auth boundary is explicit for each route class.
- [x] Error shape is machine-readable and stable.
