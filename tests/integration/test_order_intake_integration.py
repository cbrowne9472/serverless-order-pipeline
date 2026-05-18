"""
Integration tests — require a live AWS environment.

Run with:
    AWS_PROFILE=<profile> API_BASE_URL=<url from terraform output> pytest tests/integration/ -v

The API_BASE_URL is printed by `terraform output api_base_url` from environments/dev.
"""

import json
import os

import boto3
import pytest
import urllib.request
import urllib.error

API_BASE_URL = os.environ.get("API_BASE_URL", "")
ORDERS_TABLE = os.environ.get("ORDERS_TABLE", "")

pytestmark = pytest.mark.skipif(
    not API_BASE_URL,
    reason="API_BASE_URL not set — skipping integration tests",
)

VALID_ORDER = {
    "customer_email": "integration-test@example.com",
    "item_id": "ITEM-001",
    "quantity": 1,
    "shipping_address": {
        "line1": "123 Main St",
        "city": "Austin",
        "state": "TX",
        "zip": "78701",
        "country": "US",
    },
}


def _post(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(
        f"{API_BASE_URL}{path}",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())


def test_place_order_returns_201_with_order_id():
    status, body = _post("/orders", VALID_ORDER)
    assert status == 201
    assert "order_id" in body
    assert body["status"] == "PENDING"


def test_place_order_saves_to_dynamodb():
    if not ORDERS_TABLE:
        pytest.skip("ORDERS_TABLE not set")

    status, body = _post("/orders", VALID_ORDER)
    assert status == 201

    dynamodb = boto3.resource("dynamodb")
    table = dynamodb.Table(ORDERS_TABLE)
    item = table.get_item(Key={"order_id": body["order_id"]}).get("Item")

    assert item is not None
    assert item["status"] == "PENDING"
    assert item["customer_email"] == VALID_ORDER["customer_email"]


def test_missing_field_returns_400():
    status, body = _post("/orders", {"customer_email": "x@x.com"})
    assert status == 400
    assert "error" in body
