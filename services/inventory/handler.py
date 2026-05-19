import json
import os
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource("dynamodb")
events_client = boto3.client("events")


class InsufficientStockError(Exception):
    pass


def lambda_handler(event, context):
    order = event["detail"]
    order_id = order["order_id"]
    item_id = order["item_id"]
    quantity = order["quantity"]

    try:
        _reserve_inventory(item_id, quantity)
        _update_order_status(order_id, "INVENTORY_RESERVED")
        _publish_event("InventoryReserved", order)
    except InsufficientStockError:
        _update_order_status(order_id, "INVENTORY_INSUFFICIENT")
        _publish_event("InventoryInsufficient", {
            **order,
            "failure_reason": f"Insufficient stock for item {item_id}",
        })


def _reserve_inventory(item_id, quantity):
    table = dynamodb.Table(os.environ["INVENTORY_TABLE"])

    try:
        table.update_item(
            Key={"item_id": item_id},
            # Atomically decrement quantity — fails if stock would go negative
            UpdateExpression="SET quantity = quantity - :qty",
            ConditionExpression="quantity >= :qty AND attribute_exists(item_id)",
            ExpressionAttributeValues={":qty": quantity},
        )
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            raise InsufficientStockError(f"Stock check failed for {item_id}")
        raise


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
