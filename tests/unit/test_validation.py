import importlib.util
import json
import os
import sys
from unittest.mock import MagicMock, call, patch

import pytest

os.environ.setdefault("ORDERS_TABLE", "test-orders-table")
os.environ.setdefault("EVENT_BUS_NAME", "test-event-bus")

_spec = importlib.util.spec_from_file_location(
    "validation_handler",
    os.path.join(os.path.dirname(__file__), "../../services/validation/handler.py"),
)
handler = importlib.util.module_from_spec(_spec)
sys.modules["validation_handler"] = handler
_spec.loader.exec_module(handler)


def _event(order):
    return {"detail": order}


BASE_ORDER = {
    "order_id": "order-abc-123",
    "customer_email": "test@example.com",
    "item_id": "ITEM-001",
    "quantity": 2,
    "status": "PENDING",
    "shipping_address": {
        "line1": "123 Main St",
        "city": "Austin",
        "state": "TX",
        "zip": "78701",
        "country": "US",
    },
}


# --- happy path ---

@patch("validation_handler.events_client")
@patch("validation_handler.dynamodb")
def test_valid_order_updates_status_to_validated(mock_dynamo, mock_events):
    mock_dynamo.Table.return_value = MagicMock()
    mock_events.put_events.return_value = {"FailedEntryCount": 0, "Entries": [{}]}

    handler.lambda_handler(_event(BASE_ORDER), {})

    update_call = mock_dynamo.Table.return_value.update_item.call_args
    assert update_call[1]["ExpressionAttributeValues"][":status"] == "VALIDATED"


@patch("validation_handler.events_client")
@patch("validation_handler.dynamodb")
def test_valid_order_publishes_order_validated(mock_dynamo, mock_events):
    mock_dynamo.Table.return_value = MagicMock()
    mock_events.put_events.return_value = {"FailedEntryCount": 0, "Entries": [{}]}

    handler.lambda_handler(_event(BASE_ORDER), {})

    entry = mock_events.put_events.call_args[1]["Entries"][0]
    assert entry["DetailType"] == "OrderValidated"
    assert json.loads(entry["Detail"])["order_id"] == BASE_ORDER["order_id"]


# --- invalid item ---

@patch("validation_handler.events_client")
@patch("validation_handler.dynamodb")
def test_unknown_item_sets_validation_failed(mock_dynamo, mock_events):
    mock_dynamo.Table.return_value = MagicMock()
    mock_events.put_events.return_value = {"FailedEntryCount": 0, "Entries": [{}]}

    order = {**BASE_ORDER, "item_id": "ITEM-FAKE"}
    handler.lambda_handler(_event(order), {})

    update_call = mock_dynamo.Table.return_value.update_item.call_args
    assert update_call[1]["ExpressionAttributeValues"][":status"] == "VALIDATION_FAILED"


@patch("validation_handler.events_client")
@patch("validation_handler.dynamodb")
def test_unknown_item_publishes_order_validation_failed(mock_dynamo, mock_events):
    mock_dynamo.Table.return_value = MagicMock()
    mock_events.put_events.return_value = {"FailedEntryCount": 0, "Entries": [{}]}

    order = {**BASE_ORDER, "item_id": "ITEM-FAKE"}
    handler.lambda_handler(_event(order), {})

    entry = mock_events.put_events.call_args[1]["Entries"][0]
    assert entry["DetailType"] == "OrderValidationFailed"
    detail = json.loads(entry["Detail"])
    assert "failure_reason" in detail


# --- quantity validation ---

@pytest.mark.parametrize("quantity", [0, -1, 101])
@patch("validation_handler.events_client")
@patch("validation_handler.dynamodb")
def test_invalid_quantity_fails_validation(mock_dynamo, mock_events, quantity):
    mock_dynamo.Table.return_value = MagicMock()
    mock_events.put_events.return_value = {"FailedEntryCount": 0, "Entries": [{}]}

    order = {**BASE_ORDER, "quantity": quantity}
    handler.lambda_handler(_event(order), {})

    entry = mock_events.put_events.call_args[1]["Entries"][0]
    assert entry["DetailType"] == "OrderValidationFailed"


# --- address validation ---

@pytest.mark.parametrize("missing_field", ["line1", "city", "state", "zip", "country"])
@patch("validation_handler.events_client")
@patch("validation_handler.dynamodb")
def test_missing_address_field_fails_validation(mock_dynamo, mock_events, missing_field):
    mock_dynamo.Table.return_value = MagicMock()
    mock_events.put_events.return_value = {"FailedEntryCount": 0, "Entries": [{}]}

    address = {k: v for k, v in BASE_ORDER["shipping_address"].items() if k != missing_field}
    order = {**BASE_ORDER, "shipping_address": address}
    handler.lambda_handler(_event(order), {})

    entry = mock_events.put_events.call_args[1]["Entries"][0]
    assert entry["DetailType"] == "OrderValidationFailed"
