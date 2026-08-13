# Contract

| FRn | interface | request | response | failure | access |
|-----|-----------|---------|----------|---------|--------|
| FR1 | POST /tasks | {title} | 201 {id,title,done:false} | 400 {error} | token |
| FR1 | GET /tasks | - | 200 [task] | - | token |
| FR2 | POST /tasks/{id}/done | - | 200 {id,done:true} | 404 {error} | token |
