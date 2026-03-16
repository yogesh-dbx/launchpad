"""Zerobus producer: ingests events into INGEST_TABLE_NAME.

Usage:
    export ZEROBUS_SERVER_ENDPOINT="..."
    export DATABRICKS_WORKSPACE_URL="..."
    export DATABRICKS_CLIENT_ID="..."
    export DATABRICKS_CLIENT_SECRET="..."
    python producer.py --count 1000 --batch-size 100
"""

import argparse
import logging
import sys
import time

from zerobus.sdk.sync import ZerobusSdk
from zerobus.sdk.shared import RecordType, StreamConfigurationOptions, TableProperties

import INGEST_PROTO_MODULE
from config import get_config

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)


def ingest_events(events: list[dict], config: dict, batch_size: int = 100):
    """Ingest events via Zerobus with Protobuf serialization and retry."""
    sdk = ZerobusSdk(config["server_endpoint"], config["workspace_url"])

    options = StreamConfigurationOptions(record_type=RecordType.PROTO)
    table_props = TableProperties(
        config["table_name"],
        INGEST_PROTO_MODULE.INGEST_MESSAGE_NAME.DESCRIPTOR,
    )

    stream = sdk.create_stream(
        config["client_id"], config["client_secret"], table_props, options
    )

    ingested = 0
    failed = 0
    start_time = time.time()

    try:
        for i, event in enumerate(events):
            record = INGEST_PROTO_MODULE.INGEST_MESSAGE_NAME(**event)

            for attempt in range(3):
                try:
                    ack = stream.ingest_record(record)
                    ack.wait_for_ack()
                    ingested += 1
                    break
                except Exception as e:
                    err = str(e).lower()
                    logger.warning(
                        "Attempt %d/3 failed: %s", attempt + 1, e
                    )
                    if "closed" in err or "connection" in err:
                        stream.close()
                        stream = sdk.create_stream(
                            config["client_id"],
                            config["client_secret"],
                            table_props,
                            options,
                        )
                    if attempt < 2:
                        time.sleep(2**attempt)
                    else:
                        failed += 1

            if (i + 1) % batch_size == 0:
                elapsed = time.time() - start_time
                rate = (i + 1) / elapsed
                logger.info(
                    "Progress: %d/%d events (%.1f events/sec)",
                    i + 1,
                    len(events),
                    rate,
                )

        stream.flush()
    finally:
        stream.close()

    elapsed = time.time() - start_time
    logger.info(
        "Done: %d ingested, %d failed, %.1f sec (%.1f events/sec)",
        ingested,
        failed,
        elapsed,
        ingested / elapsed if elapsed > 0 else 0,
    )
    return ingested, failed


def main():
    parser = argparse.ArgumentParser(description="Ingest events via Zerobus")
    parser.add_argument(
        "--count", type=int, default=1000, help="Number of events (default: 1000)"
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=100,
        help="Log progress every N events (default: 100)",
    )
    args = parser.parse_args()

    config = get_config()
    logger.info("Ingesting %d events → %s", args.count, config["table_name"])

    # TODO: Replace with your event generation logic
    # events = generate_events(count=args.count)
    # ingested, failed = ingest_events(events, config, batch_size=args.batch_size)
    logger.error("Event generation not implemented — wire up your datagen module")
    sys.exit(1)


if __name__ == "__main__":
    main()
