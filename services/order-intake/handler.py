import json
import os
import uuid
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource("dynamodb")


def lambda_handler(event, context):
    try:
        body = _parse_body(event)
    except ValueError as e:
        return _response(400, {"error": str(e)})

    order_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).isoformat()

    order = {
        "order_id": order_id,
        "status": "PENDING",
        "customer_email": body["customer_email"],
        "item_id": body["item_id"],
        "quantity": body["quantity"],
        "shipping_address": body["shipping_address"],
        "created_at": now,
        "updated_at": now,
    }

    try:
        table = dynamodb.Table(os.environ["ORDERS_TABLE"])
        table.put_item(Item=order)
    except ClientError as e:
        print(f"DynamoDB error: {e.response['Error']['Message']}")
        return _response(500, {"error": "Failed to save order"})

    return _response(201, {"order_id": order_id, "status": "PENDING"})


def _parse_body(event):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        raise ValueError("Request body must be valid JSON")

    required = ["customer_email", "item_id", "quantity", "shipping_address"]
    missing = [f for f in required if not body.get(f)]
    if missing:
        raise ValueError(f"Missing required fields: {', '.join(missing)}")

    if not isinstance(body["quantity"], int) or body["quantity"] < 1:
        raise ValueError("quantity must be a positive integer")

    address = body["shipping_address"]
    if not isinstance(address, dict):
        raise ValueError("shipping_address must be an object")

    address_fields = ["line1", "city", "state", "zip", "country"]
    missing_address = [f for f in address_fields if not address.get(f)]
    if missing_address:
        raise ValueError(f"shipping_address missing fields: {', '.join(missing_address)}")

    return body


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type,Authorization",
            "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
        },
        "body": json.dumps(body),
    }
