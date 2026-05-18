import importlib.util
import json
import os
from unittest.mock import MagicMock, patch

import pytest

os.environ["ORDERS_TABLE"] = "test-orders-table"

import sys

_spec = importlib.util.spec_from_file_location(
    "order_intake_handler",
    os.path.join(os.path.dirname(__file__), "../../services/order-intake/handler.py"),
)
handler = importlib.util.module_from_spec(_spec)
sys.modules["order_intake_handler"] = handler
_spec.loader.exec_module(handler)


VALID_BODY = {
    "customer_email": "test@example.com",
    "item_id": "ITEM-001",
    "quantity": 2,
    "shipping_address": {
        "line1": "123 Main St",
        "city": "Austin",
        "state": "TX",
        "zip": "78701",
        "country": "US",
    },
}


def _event(body):
    return {"body": json.dumps(body)}


# --- happy path ---

@patch("order_intake_handler.dynamodb")
def test_valid_order_returns_201(mock_dynamo):
    mock_table = MagicMock()
    mock_dynamo.Table.return_value = mock_table

    response = handler.lambda_handler(_event(VALID_BODY), {})

    assert response["statusCode"] == 201
    body = json.loads(response["body"])
    assert "order_id" in body
    assert body["status"] == "PENDING"
    mock_table.put_item.assert_called_once()


@patch("order_intake_handler.dynamodb")
def test_saved_order_contains_all_fields(mock_dynamo):
    mock_table = MagicMock()
    mock_dynamo.Table.return_value = mock_table

    handler.lambda_handler(_event(VALID_BODY), {})

    saved = mock_table.put_item.call_args[1]["Item"]
    assert saved["status"] == "PENDING"
    assert saved["customer_email"] == VALID_BODY["customer_email"]
    assert saved["item_id"] == VALID_BODY["item_id"]
    assert saved["quantity"] == VALID_BODY["quantity"]
    assert "created_at" in saved
    assert "updated_at" in saved


# --- validation errors ---

@pytest.mark.parametrize("missing_field", ["customer_email", "item_id", "quantity", "shipping_address"])
def test_missing_required_field_returns_400(missing_field):
    body = {k: v for k, v in VALID_BODY.items() if k != missing_field}
    response = handler.lambda_handler(_event(body), {})
    assert response["statusCode"] == 400
    assert "error" in json.loads(response["body"])


def test_invalid_quantity_returns_400():
    body = {**VALID_BODY, "quantity": 0}
    response = handler.lambda_handler(_event(body), {})
    assert response["statusCode"] == 400


def test_non_integer_quantity_returns_400():
    body = {**VALID_BODY, "quantity": "two"}
    response = handler.lambda_handler(_event(body), {})
    assert response["statusCode"] == 400


def test_malformed_json_returns_400():
    response = handler.lambda_handler({"body": "not json"}, {})
    assert response["statusCode"] == 400


def test_missing_address_field_returns_400():
    body = {**VALID_BODY, "shipping_address": {"line1": "123 Main St"}}
    response = handler.lambda_handler(_event(body), {})
    assert response["statusCode"] == 400


# --- infrastructure errors ---

@patch("order_intake_handler.dynamodb")
def test_dynamodb_failure_returns_500(mock_dynamo):
    from botocore.exceptions import ClientError

    mock_table = MagicMock()
    mock_table.put_item.side_effect = ClientError(
        {"Error": {"Code": "InternalServerError", "Message": "DynamoDB unavailable"}},
        "PutItem",
    )
    mock_dynamo.Table.return_value = mock_table

    response = handler.lambda_handler(_event(VALID_BODY), {})
    assert response["statusCode"] == 500
