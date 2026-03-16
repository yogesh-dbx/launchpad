---
allowed-tools: Bash(databricks:*), Bash(dbx-workspace-info:*), Bash(python*), Bash(uv:*), Bash(git:*), Bash(mkdir:*), Bash(cp:*), Bash(sed:*), Bash(chmod:*), Bash(ls:*), Bash(cat:*), Read, Write, Glob, Grep, mcp__databricks__execute_sql
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
4. **Use templates, not invention.** Copy from `~/.local/share/project-templates/ingest/`, then patch placeholders.
5. **Use `dbx-workspace-info` for workspace metadata.** Do NOT call multiple APIs to discover workspace ID, host, or region. One command: `eval "$(dbx-workspace-info)"`.

---

## Phase 1: Gather Info (3 commands max)

### 1a. Parse the table name
Split the argument into `CATALOG`, `SCHEMA`, `TABLE`. Example: `my_catalog.raw.events` → catalog=`ygs`, schema=`raw`, table=`player_events`.

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

## Phase 2: Generate Files (template + patch)

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

Create `src/ingest/<table>.proto`:
```protobuf
syntax = "proto3";

message <MessageName> {
    <type> <column_name> = 1;
    <type> <column_name> = 2;
    ...
}
```

**Message name**: Convert table name to PascalCase. `player_events` → `PlayerEvent` (singular).

### 2c. Compile proto
```bash
scripts/compile_proto.sh
```
If the script doesn't exist, copy it from templates:
```bash
cp ~/.local/share/project-templates/ingest/compile_proto.sh scripts/compile_proto.sh
chmod +x scripts/compile_proto.sh
```
If the venv doesn't have `grpcio-tools`, install it:
```bash
uv pip install grpcio-tools databricks-zerobus-ingest-sdk
```
Then compile.

### 2d. Copy and patch config.py
```bash
cp ~/.local/share/project-templates/ingest/config.py src/ingest/config.py
sed -i '' "s|INGEST_TABLE_NAME|<catalog>.<schema>.<table>|g" src/ingest/config.py
```

### 2e. Copy and patch .env.example
```bash
cp ~/.local/share/project-templates/ingest/env.example src/ingest/.env.example
sed -i '' "s|INGEST_WORKSPACE_ID|$DBX_WORKSPACE_ID|g" src/ingest/.env.example
sed -i '' "s|INGEST_REGION|$DBX_REGION|g" src/ingest/.env.example
sed -i '' "s|INGEST_WORKSPACE_URL|$DBX_HOST|g" src/ingest/.env.example
sed -i '' "s|INGEST_TABLE_NAME|<catalog>.<schema>.<table>|g" src/ingest/.env.example
```

### 2f. Copy and patch producer.py
```bash
cp ~/.local/share/project-templates/ingest/producer.py src/ingest/producer.py
```
Then replace placeholders:
- `INGEST_PROTO_MODULE` → `<table>_pb2` (e.g., `player_events_pb2`)
- `INGEST_MESSAGE_NAME` → PascalCase message name (e.g., `PlayerEvent`)
- `INGEST_TABLE_NAME` → `<catalog>.<schema>.<table>`

**Important:** The producer template has a TODO for event generation. Tell the user they need to wire up their datagen module. Do NOT invent a generator — that's a separate issue.

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
