import json
import os

import boto3
from botocore.exceptions import ClientError

events_client = boto3.client("events")


def lambda_handler(event, context):
    records = event.get("Records", [])
    failures = []

    for record in records:
        if record["eventName"] != "INSERT":
            continue

        try:
            _process_record(record)
        except Exception as e:
            print(f"Failed to process record {record.get('dynamodb', {}).get('Keys')}: {e}")
            failures.append({"itemIdentifier": record["dynamodb"]["SequenceNumber"]})

    # Returning failures tells Lambda which records to retry via bisect-on-error
    return {"batchItemFailures": failures}


def _process_record(record):
    new_image = record["dynamodb"].get("NewImage")
    if not new_image:
        return

    order = _deserialize(new_image)

    response = events_client.put_events(
        Entries=[
            {
                "Source": "order-pipeline",
                "DetailType": "OrderCreated",
                "Detail": json.dumps(order),
                "EventBusName": os.environ["EVENT_BUS_NAME"],
            }
        ]
    )

    if response.get("FailedEntryCount", 0) > 0:
        raise RuntimeError(f"EventBridge rejected event: {response['Entries']}")


def _deserialize(dynamo_item):
    """Convert DynamoDB typed attribute map to a plain Python dict."""
    type_map = {
        "S": lambda v: v,
        "N": lambda v: int(v) if "." not in v else float(v),
        "BOOL": lambda v: v,
        "NULL": lambda v: None,
        "L": lambda v: [_deserialize_value(i) for i in v],
        "M": lambda v: {k: _deserialize_value(val) for k, val in v.items()},
    }
    return {k: _deserialize_value(v) for k, v in dynamo_item.items()}


def _deserialize_value(typed_value):
    for type_key, converter in {
        "S": lambda v: v,
        "N": lambda v: int(v) if "." not in v else float(v),
        "BOOL": lambda v: v,
        "NULL": lambda v: None,
        "L": lambda v: [_deserialize_value(i) for i in v],
        "M": lambda v: {k: _deserialize_value(val) for k, val in v.items()},
    }.items():
        if type_key in typed_value:
            return converter(typed_value[type_key])
    return None
