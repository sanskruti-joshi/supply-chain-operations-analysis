# Migration Validation Summary

## Execution Status

The first migration from `staging.dataco_raw` into the six public normalized
tables completed successfully.

## Source and Destination Counts

| Entity | Source distinct identifiers | Destination rows | Match |
|---|---:|---:|---|
| Category | 51 | 51 | Yes |
| Department | 11 | 11 | Yes |
| Customer | 20,652 | 20,652 | Yes |
| Product | 118 | 118 | Yes |
| Customer order | 65,752 | 65,752 | Yes |
| Order item | 180,519 | 180,519 | Yes |

- Source staging rows: 180,519
- Source staging columns: 53
- Destination order-item rows: 180,519

All source distinct identifier counts matched their corresponding destination
entity counts. The `category` table retained its existing 51 rows and was not
reinserted or truncated.

This record summarizes migration completeness only. It does not contain
customer-level data or analytical findings.
