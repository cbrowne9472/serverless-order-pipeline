"""
Full end-to-end pipeline integration test.

Requires a live AWS environment with the Stripe secret populated:
    aws secretsmanager put-secret-value --secret-id <stripe_secret_arn> --secret-string sk_test_...

Run with:
    API_BASE_URL=<url> ORDERS_TABLE=<table> pytest tests/integration/test_full_pipeline.py -v -s

Both values are printed by `terraform -chdir=terraform/environments/dev output`.
"""

import json
import os
import time
import urllib.error
import urllib.request
import uuid

import boto3
import pytest

API_BASE_URL = os.environ.get("API_BASE_URL", "")
ORDERS_TABLE = os.environ.get("ORDERS_TABLE", "")

pytestmark = pytest.mark.skipif(
    not API_BASE_URL or not ORDERS_TABLE,
    reason="API_BASE_URL and ORDERS_TABLE required — skipping integration tests",
)

VALID_ORDER = {
    "customer_email": f"integration-{uuid.uuid4().hex[:8]}@example.com",
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

TERMINAL_STATUSES = {
    "PAYMENT_CONFIRMED",
    "PAYMENT_FAILED",
    "VALIDATION_FAILED",
    "INVENTORY_INSUFFICIENT",
}


def _post_order(body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(
        f"{API_BASE_URL}/orders",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())


def _poll_order_status(order_id, timeout=30, interval=2):
    """Poll DynamoDB until the order reaches a terminal status or timeout."""
    dynamodb = boto3.resource("dynamodb")
    table = dynamodb.Table(ORDERS_TABLE)
    deadline = time.time() + timeout

    while time.time() < deadline:
        item = table.get_item(Key={"order_id": order_id}).get("Item", {})
        status = item.get("status", "")
        print(f"  order {order_id}: {status}")

        if status in TERMINAL_STATUSES:
            return status

        time.sleep(interval)

    return None  # timed out


# --- full happy path ---

def test_valid_order_reaches_payment_confirmed():
    status_code, body = _post_order(VALID_ORDER)
    assert status_code == 201, f"Expected 201, got {status_code}: {body}"

    order_id = body["order_id"]
    final_status = _poll_order_status(order_id)

    assert final_status is not None, f"Order {order_id} did not reach terminal status within timeout"
    assert final_status == "PAYMENT_CONFIRMED", f"Expected PAYMENT_CONFIRMED, got {final_status}"


# --- validation failure ---

def test_invalid_item_reaches_validation_failed():
    order = {**VALID_ORDER, "item_id": "ITEM-INVALID"}
    status_code, body = _post_order(order)
    assert status_code == 201

    final_status = _poll_order_status(body["order_id"])
    assert final_status == "VALIDATION_FAILED"


# --- API-level checks ---

def test_missing_field_returns_400_without_entering_pipeline():
    status_code, body = _post_order({"customer_email": "x@x.com"})
    assert status_code == 400
    assert "error" in body
