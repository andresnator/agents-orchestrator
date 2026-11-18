# Review report format

Start the report with one verdict:

| Verdict | Use it when |
| --- | --- |
| `APPROVED` | No `critical` or `warning` row is `open` or `unverified`, and no fix ran. |
| `FINDINGS` | A `critical` or `warning` row is `open` or `unverified`, or a check fails after the fix. |
| `FIXED` | The fix ran, no `critical` or `warning` row is `open` or `unverified`, and the checks pass. |

Then show the ledger. Omit the table when there are no rows.

| # | Evidence | Severity | Source | Status | Problem and fix |
| --- | --- | --- | --- | --- | --- |
| 1 | `src/cart.js:42` | critical | both | fixed | `total()` adds the discount; subtract it |

- Source: `solo`, `a`, `b`, `both`, or `defend`.
- Status: `open`, `fixed`, or `unverified`.

After the ledger, give the check result, the changed paths, and the assumptions.
