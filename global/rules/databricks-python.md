---
paths:
  - "**/*.py"
---

# Databricks Python Conventions

## Unity Catalog
- Always three-level namespace: `catalog.schema.table`
- Never reference `hive_metastore`
- Parameterize catalog/schema — never hardcode

## Serverless Compute
- Never hardcode cluster IDs
- `DATABRICKS_RUNTIME_USER` env var is NOT set on serverless — use `spark.sql("SELECT current_user()").collect()[0][0]`
- `environment_key` must be on the task object, not just in `environments`

## PySpark
- No `display()` in production code (notebook-only)
- No `dbutils.notebook.run()` — use Jobs/Workflows
- No `collect()` on large datasets
- No `spark.conf.set()` in notebooks for cluster configs
- Always set checkpoint locations for structured streaming
- Handle schema evolution in streaming pipelines

## SDP / DLT
- `cluster_by=["AUTO"]` is NOT valid in Python SDP — use actual column names
- Stop pipeline before re-running if active update exists
- Never set `development: true` on pipeline resources

## Dependencies
- Use `uv` for Python deps, not pip
- Validate imports before uploading: `python -c "import ast; ast.parse(open('file.py').read())"`

## Anti-Patterns
- No bare `except:` blocks
- No string concatenation in SQL (injection risk)
- No `os.environ.get()` without verifying the `import os` exists
