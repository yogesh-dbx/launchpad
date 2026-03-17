---
allowed-tools: Bash(databricks:*), Bash(dbx-workspace-info:*), Bash(python*), Bash(uv:*), Bash(git:*), Bash(mkdir:*), Bash(chmod:*), Bash(ls:*), Read, Write, Edit, Glob, Grep, Agent, mcp__databricks__execute_sql
description: "Scaffold Zerobus ingest: proto, producer, config, .env — from a UC table"
argument-hint: "<catalog.schema.table> (e.g., my_catalog.raw.events)"
---

# /ingest-init — Scaffold Zerobus Ingest from a UC Table

You are an ingest scaffolding agent. Given a fully-qualified table name, you produce a complete, runnable Zerobus ingest setup in `src/ingest/`.

---

## CRITICAL: Boundary Rules

1. **Require a table name.** If no argument, ask: "Which table? (e.g., my_catalog.raw.events)". Do NOT proceed without one.
2. **Never explore outside this project directory.** All work happens in `$(pwd)/src/ingest/`.
3. **Never hardcode credentials.** All secrets come from environment variables.
4. **Generate files inline with Write tool.** Do NOT copy from external template directories.
5. **Use `dbx-workspace-info` for workspace metadata.** One command: `eval "$(dbx-workspace-info)"`.
6. **Refer to the `databricks-zerobus-ingest` skill** for SDK API details and best practices.

---

## Phase 1: Gather Info (3 commands max)

### 1a. Parse the table name
Split the argument into `CATALOG`, `SCHEMA`, `TABLE`. Example: `my_catalog.raw.events` → catalog=`my_catalog`, schema=`raw`, table=`events`.

### 1b. Get workspace info
```bash
eval "$(dbx-workspace-info)"
```
This gives you: `DBX_WORKSPACE_ID`, `DBX_HOST`, `DBX_REGION`, `ZEROBUS_ENDPOINT`, `DBX_CATALOG`.

### 1c. Get table schema from UC
Use MCP SQL:
```sql
DESCRIBE TABLE <catalog>.<schema>.<table>
```
If the table doesn't exist, tell the user: "Table not found. Create it first, or provide a CREATE TABLE statement and I'll create it."

Save the column names and types for proto generation.

---

## Phase 2: Generate Files

### 2a. Create directory
```bash
mkdir -p src/ingest
```

### 2b. Generate .proto from table schema

Map Delta types to Protobuf types:
| Delta Type | Proto Type |
|-----------|------------|
| STRING | string |
| BIGINT / LONG | int64 |
| INT / INTEGER | int32 |
| DOUBLE / FLOAT | double / float |
| BOOLEAN | bool |
| TIMESTAMP | int64 (comment: microseconds) |
| DATE | string (ISO-8601) |
| BINARY | bytes |
| ARRAY/MAP/STRUCT | string (JSON-serialized) |

Write `src/ingest/<table>.proto` using the Write tool:
```protobuf
syntax = "proto3";

message <MessageName> {
    <type> <column_name> = 1;
    <type> <column_name> = 2;
    ...
}
```

**Message name**: Convert table name to PascalCase. `player_events` → `PlayerEvent` (singular).

### 2c. Generate compile_proto.sh and compile
Write `scripts/compile_proto.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
PROTO_DIR="src/ingest"
python -m grpc_tools.protoc -I="$PROTO_DIR" --python_out="$PROTO_DIR" "$PROTO_DIR"/*.proto
echo "✓ Proto compiled"
```
Make it executable and install deps if needed:
```bash
chmod +x scripts/compile_proto.sh
uv pip install grpcio-tools databricks-zerobus-ingest-sdk
scripts/compile_proto.sh
```

### 2d. Generate config.py
Write `src/ingest/config.py` with the Write tool:
```python
"""Zerobus ingest configuration — loaded from environment variables."""
import os

def get_config():
    return {
        "workspace_id": os.environ["ZEROBUS_WORKSPACE_ID"],
        "region": os.environ.get("ZEROBUS_REGION", "us-east-1"),
        "workspace_url": os.environ["ZEROBUS_WORKSPACE_URL"],
        "client_id": os.environ["ZEROBUS_CLIENT_ID"],
        "client_secret": os.environ["ZEROBUS_CLIENT_SECRET"],
        "table_name": os.environ.get("ZEROBUS_TABLE_NAME", "<catalog>.<schema>.<table>"),
    }
```
Replace `<catalog>.<schema>.<table>` with the actual table name.

### 2e. Generate .env.example
Write `src/ingest/.env.example` with actual workspace values:
```
ZEROBUS_WORKSPACE_ID=<workspace_id>
ZEROBUS_REGION=<region>
ZEROBUS_WORKSPACE_URL=<host>
ZEROBUS_TABLE_NAME=<catalog>.<schema>.<table>
ZEROBUS_CLIENT_ID=<your-service-principal-client-id>
ZEROBUS_CLIENT_SECRET=<your-service-principal-client-secret>
```

### 2f. Generate producer.py
Write `src/ingest/producer.py` using the Write tool. Include:
- Import of `<table>_pb2` and `config`
- `ZerobusSdk` initialization from config
- `create_stream()` with `TableProperties`
- A `send_event()` function that serializes a proto message and calls `ingest_record_offset` + `wait_for_offset`
- A `# TODO: wire up your event generator here` marker in `__main__`

**Important:** Do NOT invent a data generator — that's a separate issue. Just leave the TODO.

### 2g. Ensure .env is gitignored
Check `.gitignore` for `.env`. If missing, add:
```
# Secrets
.env
*.secret
```

---

## Phase 3: Verify

### 3a. Verify proto compiles
```bash
ls -la src/ingest/<table>_pb2.py
```

### 3b. Verify imports work
```python
import sys
sys.path.insert(0, "src/ingest")
from config import get_config
import <table>_pb2
msg = <table>_pb2.<MessageName>()
print(f"Proto fields: {[f.name for f in msg.DESCRIPTOR.fields]}")
```

### 3c. Verify file count
```bash
ls src/ingest/
```
Expected: `config.py`, `.env.example`, `producer.py`, `<table>.proto`, `<table>_pb2.py`

---

## Phase 4: Report

Print a summary table:

```
┌──────────────────────┬──────────────────────────────────────────┐
│ File                 │ Purpose                                  │
├──────────────────────┼──────────────────────────────────────────┤
│ <table>.proto        │ Protobuf schema (<N> fields)             │
│ <table>_pb2.py       │ Compiled bindings (auto-generated)       │
│ config.py            │ Env-var config loader                    │
│ producer.py          │ Producer with retry + reconnection       │
│ .env.example         │ Template (endpoint pre-filled)           │
└──────────────────────┴──────────────────────────────────────────┘

Zerobus endpoint: <workspace_id>.zerobus.<region>.cloud.databricks.com
Target table:     <catalog>.<schema>.<table>

⚠ Before running:
1. Create a service principal in Account Console → Generate Secret
2. Grant UC permissions:
   GRANT USE CATALOG ON CATALOG <catalog> TO `<sp-uuid>`;
   GRANT USE SCHEMA ON SCHEMA <catalog>.<schema> TO `<sp-uuid>`;
   GRANT MODIFY, SELECT ON TABLE <catalog>.<schema>.<table> TO `<sp-uuid>`;
3. Copy src/ingest/.env.example → .env and fill in CLIENT_ID + CLIENT_SECRET
4. Wire up your event generator in producer.py (see the TODO)
```

---

## Anti-Patterns

- **Do NOT call `databricks api get` multiple times** to discover workspace info. Use `dbx-workspace-info`.
- **Do NOT try to install the SDK on serverless.** It's not available. Always use local venv.
- **Do NOT generate the event generator.** That's domain-specific and belongs in a separate issue.
- **Do NOT write the proto by hand** if you can DESCRIBE the table. Only hand-write if the table doesn't exist yet.
- **Do NOT use system python** for protoc. Always use the project venv: `.venv/bin/python`.
