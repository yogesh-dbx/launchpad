---
paths:
  - "**/*.sql"
---

# Databricks SQL Conventions

## Unity Catalog
- Always three-level namespace: `catalog.schema.table`
- Column in `information_schema.tables` is `table_name`, not `name`
- Use `table_catalog`, `table_schema`, `table_name` — not shorthand
- Don't query `system.information_schema.registered_models` — use MLflow API or `SHOW MODELS IN catalog.schema`

## Medallion Architecture
- `raw` (bronze) — source data as-is, append-only
- `cleansed` (silver) — cleaned, deduplicated, typed
- `curated` (gold) — business aggregations, features, metrics

## Naming
- Table names: `snake_case`, descriptive
- Column names: `snake_case` lowercase
- Avoid SQL reserved words as identifiers

## Metric Views
- `manage_metric_views(action: "create")` generates broken YAML — use `CREATE OR REPLACE VIEW ... WITH METRICS LANGUAGE YAML AS $$ ... $$` DDL directly via `execute_sql`

## Style
- Use parameterized queries — never string concatenation
- Include WHERE clauses — no unbounded SELECT *
- Use CTEs over nested subqueries for readability
