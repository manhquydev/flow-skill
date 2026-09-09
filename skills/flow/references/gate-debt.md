## Debt (deliberate skips)
If the operator deliberately skips/reorders a gate, ensure a line opens in `DEBT.md` naming
the skip, the concrete exposure, and the close condition. **Security-class skips** (auth,
admin exposure, tenancy, payments) are never silent and never your decision — the operator
accepts the exposure in writing. In `/flow auto`, that is a Tier-C halt.
