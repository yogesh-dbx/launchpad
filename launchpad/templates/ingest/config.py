"""Zerobus ingest configuration — all values from environment variables."""

import os
import sys


def get_config() -> dict:
    """Load Zerobus config from environment variables. Exits on missing values."""
    required = {
        "ZEROBUS_SERVER_ENDPOINT": "Zerobus gRPC endpoint (e.g., <workspace-id>.zerobus.<region>.cloud.databricks.com)",
        "DATABRICKS_WORKSPACE_URL": "Workspace URL (e.g., https://my-workspace.cloud.databricks.com)",
        "DATABRICKS_CLIENT_ID": "Service principal client ID",
        "DATABRICKS_CLIENT_SECRET": "Service principal client secret",
    }

    missing = [k for k in required if not os.environ.get(k)]
    if missing:
        print("Missing required environment variables:", file=sys.stderr)
        for k in missing:
            print(f"  {k} — {required[k]}", file=sys.stderr)
        sys.exit(1)

    return {
        "server_endpoint": os.environ["ZEROBUS_SERVER_ENDPOINT"],
        "workspace_url": os.environ["DATABRICKS_WORKSPACE_URL"],
        "table_name": os.environ.get("ZEROBUS_TABLE_NAME", "INGEST_TABLE_NAME"),
        "client_id": os.environ["DATABRICKS_CLIENT_ID"],
        "client_secret": os.environ["DATABRICKS_CLIENT_SECRET"],
    }
