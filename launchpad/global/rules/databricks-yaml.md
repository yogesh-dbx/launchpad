---
paths:
  - "**/*.yml"
  - "**/*.yaml"
  - "**/databricks.yml"
---

# Databricks YAML / DABs Conventions

## Asset Bundles (databricks.yml)
- Never set `development: true` on pipeline resources — let `mode: development` on the target handle it
- `mode: production` requires `workspace.root_path`
- Parameterize catalog, schema, warehouse_id as variables
- Use serverless compute — never hardcode cluster IDs

## Metric View YAML
- version: 1.1
- source must be valid Spark SQL (not Tableau notation)
- No `[field]` bracket references — use SQL column names
- LOD expressions → window functions in source SQL
- Validate: balanced parens, no Tableau syntax leaks

## Pipeline Config
- Stop pipeline before re-running if active update exists
- Serverless DLT/SDP may not have UC catalog access on all workspaces
