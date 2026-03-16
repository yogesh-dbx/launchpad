#!/usr/bin/env bash
# Compile .proto files in src/ingest/ using the project venv
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_PYTHON="$PROJECT_ROOT/.venv/bin/python"

if [[ ! -x "$VENV_PYTHON" ]]; then
    echo "No venv found. Creating one and installing grpcio-tools..."
    cd "$PROJECT_ROOT"
    uv venv
    uv pip install grpcio-tools databricks-zerobus-ingest-sdk
fi

INGEST_DIR="$PROJECT_ROOT/src/ingest"
PROTO_FILES=$(find "$INGEST_DIR" -name "*.proto" 2>/dev/null)

if [[ -z "$PROTO_FILES" ]]; then
    echo "No .proto files found in $INGEST_DIR"
    exit 1
fi

for proto in $PROTO_FILES; do
    echo "Compiling $(basename "$proto")..."
    "$VENV_PYTHON" -m grpc_tools.protoc \
        -I"$INGEST_DIR" \
        --python_out="$INGEST_DIR" \
        "$proto"
done

echo "Done. Compiled proto bindings in $INGEST_DIR/"
