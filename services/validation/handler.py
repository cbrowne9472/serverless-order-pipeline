import json
import os
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource("dynamodb")
events_client = boto3.client("events")

# Catalog of valid item IDs — in a real system this would be a DynamoDB lookup
VALID_ITEMS = {"ITEM-001", "ITEM-002", "ITEM-003", "ITEM-004", "ITEM-005"}
MAX_QUANTITY = 100

REQUIRED_ADDRESS_FIELDS = {"line1", "city", "state", "zip", "country"}


class ValidationError(Exception):
    pass


def lambda_handler(event, context):
    order = event["detail"]
    order_id = order["order_id"]

    try:
        _validate(order)
        _update_order_status(order_id, "VALIDATED")
        _publish_event("OrderValidated", order)
    except ValidationError as e:
        _update_order_status(order_id, "VALIDATION_FAILED")
        _publish_event("OrderValidationFailed", {**order, "failure_reason": str(e)})


def _validate(order):
    item_id = order.get("item_id", "")
    if item_id not in VALID_ITEMS:
        raise ValidationError(f"Unknown item: {item_id}")

    quantity = order.get("quantity", 0)
    if not isinstance(quantity, int) or quantity < 1:
        raise ValidationError("quantity must be a positive integer")
    if quantity > MAX_QUANTITY:
        raise ValidationError(f"quantity exceeds maximum of {MAX_QUANTITY}")

    address = order.get("shipping_address", {})
    if not isinstance(address, dict):
        raise ValidationError("shipping_address must be an object")

    missing = REQUIRED_ADDRESS_FIELDS - set(address.keys())
    if missing:
        raise ValidationError(f"shipping_address missing fields: {', '.join(sorted(missing))}")


def _update_order_status(order_id, status):
    table = dynamodb.Table(os.environ["ORDERS_TABLE"])
    table.update_item(
        Key={"order_id": order_id},
        UpdateExpression="SET #s = :status, updated_at = :now",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={
            ":status": status,
            ":now": datetime.now(timezone.utc).isoformat(),
        },
    )


def _publish_event(detail_type, detail):
    events_client.put_events(
        Entries=[
            {
                "Source": "order-pipeline",
                "DetailType": detail_type,
                "Detail": json.dumps(detail),
                "EventBusName": os.environ["EVENT_BUS_NAME"],
            }
        ]
    )
