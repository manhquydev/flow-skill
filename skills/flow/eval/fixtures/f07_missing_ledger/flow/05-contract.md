# 05 — Contract

## Interfaces

| Method | Path | Access | Request | Response | Errors | Owner |
|---|---|---|---|---|---|---|
| POST | /api/orders | token | `{ sku, quantity }` | `201 { order_id, total }` | 400 invalid input; 401; 409 duplicate | order_workflow |
| GET | /api/orders/{order_id} | token | path `order_id` | `200 { order_id, total, status }` | 401; 404 | order_workflow |

## Module dependency graph

- `order_workflow -> orders_api`
- `orders_api -> pricing_core`
- `pricing_core -> none`

## Integration note

`order_workflow` calls `pricing_core.quote` while processing POST `/api/orders`.

## Error model

- Failures return `{ code, message, request_id }`; no silent 200 on failure.

## Gate

- [x] Every interface has input, output, access, and failure shapes.
- [x] Module integration considered.
- [x] Error responses are machine-readable.
