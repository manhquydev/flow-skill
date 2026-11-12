# 05 — Contract

## Interfaces

| Method | Path | Access | Request | Response | Errors | Owner |
|---|---|---|---|---|---|---|
| POST | /api/orders | token | `{ sku, quantity }` | `201 { order_id, total }` | 400 invalid input; 401; 409 duplicate | order_workflow |
| GET | /api/orders/{order_id} | token | path `order_id` | `200 { order_id, total, status }` | 401; 404 | order_workflow |

## Module dependency graph

- `order_workflow -> orders_api, pricing_core`
- `orders_api -> pricing_core`
- `pricing_core -> none`

## Dependency-seam ledger

| Host module/package | Referenced symbol/interface | Owning module/package | Required directed dependency | Creates a directed cycle in the declared graph? |
|---|---|---|---|---|
| order_workflow | `orders_api.submit_order` | orders_api | `order_workflow -> orders_api` | No — no declared path from orders_api to order_workflow |
| order_workflow | `pricing_core.quote` | pricing_core | `order_workflow -> pricing_core` | No — no declared path from pricing_core to order_workflow |
| orders_api | `pricing_core.quote` | pricing_core | `orders_api -> pricing_core` | No — no declared path from pricing_core to orders_api |

## Error model

- Failures return `{ code, message, request_id }`; no silent 200 on failure.

## Gate

- [x] Every interface has input, output, access, and failure shapes.
- [x] The declared module graph and every cross-module reference are ledgered.
- [x] Every required dependency edge has a directed-cycle result.
