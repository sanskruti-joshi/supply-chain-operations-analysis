# Supply Chain & Operations Intelligence

A PostgreSQL and SQL portfolio project exploring order, delivery, and supply-chain data from the DataCo Smart Supply Chain dataset. The current implemented work includes staging setup, import, profiling, data-quality checks, normalized migration, and an order-level delivery-performance analysis.

## Project Goals

- Validate source data and document its grain and limitations.
- Develop defensible delivery, sales, and profitability metrics.
- Explore operational patterns only when supported by the available data.
- Build reusable SQL analyses and, later, evaluate query performance.

Supplier performance and inventory risk are questions for future work: the current dataset does not establish supplier identifiers or inventory/replenishment history.

## Repository

- `data/` — source-data instructions and local datasets
- `docs/` — business context, assumptions, proposed model, data dictionary, metrics, and findings
- `sql/` — setup, import, profiling, validation, and planned analysis scripts
- `results/` — reserved for reviewed outputs

## Current SQL Progress

Run the populated scripts in order:

1. `sql/01_database_setup.sql` — creates `supply_chain_analytics` and the raw text staging table.
2. `sql/02_import_dataco.sql` — guarded `psql` `\copy` import from the local source CSV.
3. `sql/03_data_profiling.sql` — read-only profiling.
4. `sql/04_data_quality_checks.sql` — read-only consistency and anomaly checks.
5. `sql/05_schema_and_constraints.sql` — creates the normalized public schema.
6. `sql/06_data_migration.sql` — migrates source data into normalized tables.
7. `sql/07_delivery_performance.sql` — order-level delivery-performance analysis.
8. `sql/08_inventory_analysis.sql` — demand-based product, category, department, monthly, and ABC-style demand analysis.
9. `sql/09_advanced_analytics.sql` — advanced customer analytics covering purchasing profiles, recency and frequency, relative customer segmentation, repeat purchasing, customer rankings, and demand concentration.
10. `sql/10_query_optimization.sql` — Stage 10 baseline execution-plan and candidate-index investigation. It records actual B1–B3 PostgreSQL plans and validation checks without adding indexes or rewriting the analytical queries.

Findings recorded so far are summarized in [docs/findings_report.md](./docs/findings_report.md).

## Getting Started

Prerequisites: PostgreSQL and the `psql` client. The setup script must be run with a role permitted to create a database if `supply_chain_analytics` does not already exist. From PowerShell at the repository root:

```powershell
psql -X -W -U postgres -v ON_ERROR_STOP=1 -d postgres -f 'sql\01_database_setup.sql'
psql -X -W -U postgres -v ON_ERROR_STOP=1 -v replace_staging=on -d supply_chain_analytics -f 'sql\02_import_dataco.sql'
```

The import script defaults to doing nothing. `-v replace_staging=on` explicitly authorizes replacing the staging table contents; review existing data before using it. The script uses client-side `\copy` and currently names this workspace's local CSV path. If the repository is elsewhere, update only that local path in `sql/02_import_dataco.sql`.

Then connect to `supply_chain_analytics` in a SQL editor and run `sql/03_data_profiling.sql`, followed by `sql/04_data_quality_checks.sql`. These files contain regular SQL queries; setup and import use `psql` commands and are not plain SQL-editor scripts.

See [data/README.md](./data/README.md) for source and data-handling notes.

## Documentation

- [Business context](./docs/business_context.md)
- [Assumptions and limitations](./docs/assumptions_and_limitations.md)
- [ER diagram](./docs/er_diagram.md)
- [Data dictionary](./docs/data_dictionary.md)
- [Source-to-entity mapping](./docs/source_to_entity_mapping.md)
- [Metric definitions](./docs/metric_definitions.md)
- [Findings report](./docs/findings_report.md)
- [Delivery performance summary](./results/delivery_performance_summary.md)
- [Inventory analysis summary](./results/inventory_analysis_summary.md)
- [Advanced customer analytics summary](./results/advanced_analytics_summary.md)
- [Query optimization summary](./results/query_optimization_summary.md)

## Technology

- PostgreSQL
- SQL
- Visual Studio Code
- Git and GitHub

## Author

Sanskruti Joshi
