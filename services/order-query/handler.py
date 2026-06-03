import json
import os

import boto3

dynamodb = boto3.resource("dynamodb")
ORDERS_TABLE = os.environ["ORDERS_TABLE"]

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type,Authorization",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
}


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": CORS_HEADERS,
        "body": json.dumps(body, default=str),
    }


def lambda_handler(event, context):
    if event.get("httpMethod") == "OPTIONS":
        return _response(200, {})

    path_params = event.get("pathParameters") or {}
    query_params = event.get("queryStringParameters") or {}
    order_id = path_params.get("order_id")

    if order_id:
        return _get_order(order_id)
    return _list_orders(limit=int(query_params.get("limit", 50)))


def _get_order(order_id):
    table = dynamodb.Table(ORDERS_TABLE)
    result = table.get_item(Key={"order_id": order_id})
    item = result.get("Item")

    if not item:
        return _response(404, {"error": "Order not found"})

    return _response(200, item)


def _list_orders(limit=50):
    table = dynamodb.Table(ORDERS_TABLE)
    result = table.scan(Limit=limit)
    items = result.get("Items", [])

    # Sort newest first
    items.sort(key=lambda x: x.get("created_at", ""), reverse=True)

    return _response(200, {"orders": items, "count": len(items)})
