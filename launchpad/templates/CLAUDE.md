# Project: PROJECT_NAME

## Session Contract

Before doing ANY work in this project, read this entire file. If this is the start of a session, confirm you understand by stating:
1. The catalog and schemas you'll use
2. The compute type (serverless)
3. The branch strategy (never commit to main)

Do not write code until you have confirmed these three things.

---

## Environment

- **Databricks Profile:** `DATABRICKS_PROFILE`
- **Catalog:** `PROJECT_CATALOG`
- **Schemas:** `PROJECT_CATALOG.raw` (bronze), `PROJECT_CATALOG.cleansed` (silver), `PROJECT_CATALOG.curated` (gold)
- **Warehouse:** Serverless Starter Warehouse (via DAB variable lookup)
- **Python:** managed by `uv`

---

## Databricks Conventions

### Serverless First
Always use serverless compute. Never hardcode cluster IDs. Use `warehouse_id` variable lookup in `databricks.yml`.

### Unity Catalog
Always use three-level namespace: `catalog.schema.table`. Never reference `hive_metastore`. Parameterize catalog and schema names — never hardcode them.

### Medallion Architecture
- **raw** (bronze) — source data as-is, append-only
- **cleansed** (silver) — cleaned, deduplicated, typed
- **curated** (gold) — business-level aggregations, features, metrics

### Secrets
Never hardcode tokens, passwords, or API keys. Use `dbutils.secrets.get(scope, key)` or Databricks secret scopes.

### Deployment
Use Databricks Asset Bundles (DABs): `databricks bundle deploy --target dev`. CI/CD auto-deploys on push to `main` via GitHub Actions.

---

## Skills

Prefer project-level skills in `.claude/skills/` over general knowledge for Databricks tasks. Check available skills before answering Databricks questions.

### Skill Invocation
When using the Skill tool, always use the **fully-qualified name** (`plugin:skill`):
- ✅ `feature-dev:feature-dev` — correct
- ❌ `feature-dev` — will fail with "Unknown skill"
- ✅ `commit-commands:commit` — correct
- ❌ `commit` — will fail

---

## Branch Strategy

- `main` — stable, always deployable. Never commit directly.
- `feature/*` — new features (e.g., `feature/add-streaming-pipeline`)
- `fix/*` — bug fixes
- `docs/*` — documentation only
- `chore/*` — repo maintenance

### Commits
Use conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`, `test:`
Reference issue numbers: `feat: add SDP pipeline (#3)`

---

## Commands

- `/plan <use case>` — break a use case into PLAN.md + GitHub issues + Projects v2 board
- `/ship [title]` — test → commit → push → PR in one command
- `/demo-prep [topic]` — prepare code for a customer demo
- `/techdebt [area]` — analyze code for tech debt and improvements
- `/customer-review` — review code quality before delivery

---

## Output Format

- **Pipeline files:** imports → config/parameters → transformations → write target (no business logic in notebooks)
- **Scripts:** docstring with purpose → main function → `if __name__ == "__main__"` guard
- **DAB resource YAML:** name → compute → depends_on → parameters (match existing `resources/` patterns)
- **Test files:** one test class per source module, at least one edge case per test function
- **SQL:** parameterized with variables, never string concatenation

---

## Shipping Rule

**NEVER manually `git commit` / `git push` / `gh pr create`.** Always use `/ship` after writing code. The `/ship` command handles everything: test → commit → push → PR → **execute on Databricks** → **validate output** → **close the issue**. Skipping `/ship` means the code is pushed but never actually run or validated — that is NOT done.

If a plugin (e.g., `feature-dev:feature-dev`) tries to commit/push on its own, **stop it** and run `/ship` instead.

---

## Failure Conditions

Output is **unacceptable** if any of these are true:

- Code references `hive_metastore` instead of Unity Catalog three-level namespace
- SQL or Python contains hardcoded catalog or schema names instead of variables
- Streaming pipeline is missing checkpoint location configuration
- Any secret, token, or password appears in code (even as placeholder like `xxx` or `changeme`)
- Code uses `collect()` on an unbounded dataset
- A PR is created without a linked GitHub issue
- Commit messages don't follow conventional commits (`feat:`, `fix:`, `docs:`, etc.)
- Test files only test happy paths with no edge cases
- Pipeline resource YAML has `development: true` hardcoded (let target mode control it)
- API signatures are used without checking official Databricks documentation
- Code uses `display()` outside of a notebook context
- `os.getcwd()` is used for file paths in a notebook (use absolute workspace paths)
- Code uses `dbutils.notebook.run()` instead of Jobs/Workflows
- `spark.conf.set()` is used in notebooks for cluster-level configs

---

## Anti-Slop Rules

DO NOT generate:
- Verbose comments that restate the code (`# increment counter by 1`)
- Unnecessary abstractions or wrapper classes
- Over-engineered solutions for simple problems
- Placeholder/stub implementations without real logic
- Excessive logging that clutters output
- Type hints on obvious assignments (`x: int = 5`)

DO:
- Write concise, readable code
- Use descriptive variable names instead of comments
- Keep functions under 30 lines
- Prefer flat over nested
- Handle errors explicitly — no bare `except:` blocks
- Test edge cases, not happy paths

---

## Serverless Jobs — Known Gotchas

- **`environment_key` must be on the task, not just in `environments`.** When creating a serverless job via `manage_jobs`, each task needs `"environment_key": "default"` as a top-level field on the task object. Defining `environments` at the job level is not enough — the task must reference it explicitly.
- **`get_output` fails on multi-task runs.** `manage_job_runs(action: "get_output")` only works on single-task runs. For multi-task runs: first `get` the run to find individual task `run_id`s, then call `get_output` on each task run.
- **MLflow experiment path: use `/Users/{user}/`, not `/Shared/`.** The `/Shared/` directory may not exist on the workspace. Always use `/Users/{DATABRICKS_RUNTIME_USER}/project_name/experiment_name` for MLflow experiments — the user's home directory always exists.
- **`DATABRICKS_RUNTIME_USER` env var is NOT set on serverless compute.** Use `spark.sql("SELECT current_user()").collect()[0][0]` to get the authenticated user reliably across all compute types. Never fall back to a hardcoded default like `"shared"`.
- **Validate imports before uploading.** When adding code that uses a new module (e.g., `os.environ.get()`), always verify the corresponding `import` is present. Run a quick syntax check (`python -c "import ast; ast.parse(open('file.py').read())"`) before uploading to Databricks.
- **UC model registry: don't query `system.information_schema.registered_models` or `model_versions`.** These system tables may not exist on all workspaces. Instead use MLflow Python API (`mlflow.MlflowClient().search_registered_models()`) or SQL: `SHOW MODELS IN catalog.schema`.
- **`information_schema.tables` column is `table_name`, not `name`.** Always use `table_name`, `table_catalog`, `table_schema` — not shorthand like `name` or `catalog_name`.

---

## SDP — Known Gotchas

- **`cluster_by=["AUTO"]` is NOT valid in Python SDP.** The `cluster_by` parameter in `@dp.table()` and `@dp.materialized_view()` accepts only a list of **actual column names** (e.g., `["event_type", "player_id"]`). `"AUTO"` is SQL-only syntax (`CLUSTER BY AUTO`) for DBSQL materialized views — using it in Python causes `DELTA_COLUMN_NOT_FOUND_IN_SCHEMA`.
- **Pre-existing managed table conflict.** If a regular managed Delta table already exists with the same name as an SDP target, the pipeline fails with "Could not materialize because a MANAGED table already exists." Schema init scripts must NOT create tables that SDP pipelines will manage. If they already exist, `DROP TABLE IF EXISTS` before first pipeline run.
- **Stop before re-running.** Always stop a pipeline before starting a new update if a previous update is still active. Otherwise: "An active update already exists for pipeline."

---

## DABs — Known Gotchas

- **Never set `development: true` on pipeline resources** — let `mode: development` on the target handle it. Hardcoding it causes `mode: production` validation to fail.
- **`mode: production` requires `workspace.root_path`** — already set in `databricks.yml` prod target.
- **`databricks bundle deploy` may intermittently fail with "Catalog does not exist"** — this can happen due to stale Terraform state from previous failed deployments. Fix: delete `.databricks/bundle/` directory and retry. If it persists, deploy via MCP `create_or_update_pipeline` as a fallback.

---

## Zerobus Ingest — Known Gotchas

- **Use "SDP" (Spark Declarative Pipelines), not "DLT" (Delta Live Tables)** — they are the same product, SDP is the current name.
- **Timestamps must be Unix microseconds (int64)**, not ISO-8601 strings: `int(datetime.now().timestamp() * 1_000_000)`
- **`os.getcwd()` in serverless notebooks returns the notebook's directory**, not the project root. Always use absolute workspace paths when referencing other project files.
- **Error 4024 "Unsupported table kind"** — Zerobus cannot write to catalogs using the metastore's default managed storage (`s3://dbstorage-prod-*`). Check with `databricks catalogs get <name>` — if `storage_root` contains `dbstorage-prod`, use a catalog with a dedicated S3 bucket instead. This does NOT affect SDP pipelines — only Zerobus Ingest.
- **OAuth secrets for service principals require the Account Console** — the workspace API cannot generate them. Do not attempt to automate this. Tell the user to generate it manually from Account Console → Service Principals → Generate Secret.
- **`AckCallback` must be a subclass**, not a plain function or lambda. For simplicity, skip the callback and use synchronous ingestion (`ingest_record_offset` + `wait_for_offset`).
- **SDK v1.1.0 breaking changes** — The `databricks-zerobus-ingest-sdk>=1.0` has a new API: `ZerobusSdk(host=, unity_catalog_url=)` → `.create_stream(client_id=, client_secret=, table_properties=, options=)`. `TableProperties(table_name=)` replaces `uc_table_name`. Default record type is PROTO; set `options.record_type = RecordType.JSON` for JSON. JSON payloads must be `str` not `bytes`.
- **`databricks-zerobus-ingest-sdk` cannot be pip-installed on serverless compute** — the package isn't available on the serverless pip index. Run Zerobus producers locally or on a cluster, not in serverless notebooks.
- **No clusters? Use serverless Jobs API** — `runs/submit` with an `environments` spec runs notebooks on serverless compute without any cluster.

---

## Before Writing Tests or New Code

1. **Read existing code first** — check `scripts/` for install scripts, `src/` for working patterns, `requirements.txt` / `pyproject.toml` for package names. Never guess package names or API signatures.
2. **Verify SDK versions** — use `inspect.signature(Class.__init__)` to confirm constructor args before writing code. SDK APIs change between major versions.
3. **Check environment constraints** — know whether code runs on serverless, cluster, or local. Not all pip packages are available on serverless compute.
4. **One failure = diagnose, two = switch approach** — if pip install fails on serverless, try local immediately. Don't retry the same failing approach 4 times.
5. **After catalog/schema changes** — re-grant service principal permissions and update all config references (databricks.yml, CLAUDE.md, source code).
