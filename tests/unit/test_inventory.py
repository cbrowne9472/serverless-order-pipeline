import importlib.util
import json
import os
import sys
from unittest.mock import MagicMock, patch

import pytest
from botocore.exceptions import ClientError

os.environ.setdefault("INVENTORY_TABLE", "test-inventory-table")
os.environ.setdefault("ORDERS_TABLE", "test-orders-table")
os.environ.setdefault("EVENT_BUS_NAME", "test-event-bus")

_spec = importlib.util.spec_from_file_location(
    "inventory_handler",
    os.path.join(os.path.dirname(__file__), "../../services/inventory/handler.py"),
)
handler = importlib.util.module_from_spec(_spec)
sys.modules["inventory_handler"] = handler
_spec.loader.exec_module(handler)


BASE_ORDER = {
    "order_id": "order-abc-123",
    "customer_email": "test@example.com",
    "item_id": "ITEM-001",
    "quantity": 2,
    "status": "VALIDATED",
    "shipping_address": {
        "line1": "123 Main St",
        "city": "Austin",
        "state": "TX",
        "zip": "78701",
        "country": "US",
    },
}


def _client_error(code):
    return ClientError({"Error": {"Code": code, "Message": code}}, "UpdateItem")


# --- happy path ---

@patch("inventory_handler.events_client")
@patch("inventory_handler.dynamodb")
def test_sufficient_stock_reserves_inventory(mock_dynamo, mock_events):
    mock_dynamo.Table.return_value = MagicMock()
    mock_events.put_events.return_value = {"FailedEntryCount": 0, "Entries": [{}]}

    handler.lambda_handler({"detail": BASE_ORDER}, {})

    # Inventory table should be updated with conditional write
    inventory_table = mock_dynamo.Table.return_value
    call_kwargs = inventory_table.update_item.call_args_list[0][1]
    assert call_kwargs["Key"] == {"item_id": "ITEM-001"}
    assert ":qty" in call_kwargs["ExpressionAttributeValues"]
    assert call_kwargs["ExpressionAttributeValues"][":qty"] == 2


@patch("inventory_handler.events_client")
@patch("inventory_handler.dynamodb")
def test_sufficient_stock_publishes_inventory_reserved(mock_dynamo, mock_events):
    mock_dynamo.Table.return_value = MagicMock()
    mock_events.put_events.return_value = {"FailedEntryCount": 0, "Entries": [{}]}

    handler.lambda_handler({"detail": BASE_ORDER}, {})

    entry = mock_events.put_events.call_args[1]["Entries"][0]
    assert entry["DetailType"] == "InventoryReserved"
    assert json.loads(entry["Detail"])["order_id"] == BASE_ORDER["order_id"]


@patch("inventory_handler.events_client")
@patch("inventory_handler.dynamodb")
def test_sufficient_stock_sets_inventory_reserved_status(mock_dynamo, mock_events):
    mock_dynamo.Table.return_value = MagicMock()
    mock_events.put_events.return_value = {"FailedEntryCount": 0, "Entries": [{}]}

    handler.lambda_handler({"detail": BASE_ORDER}, {})

    # Second update_item call is the order status update
    orders_update = mock_dynamo.Table.return_value.update_item.call_args_list[1][1]
    assert orders_update["ExpressionAttributeValues"][":status"] == "INVENTORY_RESERVED"


# --- insufficient stock ---

@patch("inventory_handler.events_client")
@patch("inventory_handler.dynamodb")
def test_conditional_check_failure_publishes_inventory_insufficient(mock_dynamo, mock_events):
    mock_table = MagicMock()
    mock_table.update_item.side_effect = [
        _client_error("ConditionalCheckFailedException"),  # inventory check fails
        MagicMock(),                                        # order status update
    ]
    mock_dynamo.Table.return_value = mock_table
    mock_events.put_events.return_value = {"FailedEntryCount": 0, "Entries": [{}]}

    handler.lambda_handler({"detail": BASE_ORDER}, {})

    entry = mock_events.put_events.call_args[1]["Entries"][0]
    assert entry["DetailType"] == "InventoryInsufficient"
    detail = json.loads(entry["Detail"])
    assert "failure_reason" in detail


@patch("inventory_handler.events_client")
@patch("inventory_handler.dynamodb")
def test_insufficient_stock_sets_inventory_insufficient_status(mock_dynamo, mock_events):
    mock_table = MagicMock()
    mock_table.update_item.side_effect = [
        _client_error("ConditionalCheckFailedException"),
        MagicMock(),
    ]
    mock_dynamo.Table.return_value = mock_table
    mock_events.put_events.return_value = {"FailedEntryCount": 0, "Entries": [{}]}

    handler.lambda_handler({"detail": BASE_ORDER}, {})

    orders_update = mock_table.update_item.call_args_list[1][1]
    assert orders_update["ExpressionAttributeValues"][":status"] == "INVENTORY_INSUFFICIENT"


# --- unhandled DynamoDB errors should propagate so Lambda retries ---

@patch("inventory_handler.events_client")
@patch("inventory_handler.dynamodb")
def test_unexpected_dynamodb_error_propagates(mock_dynamo, mock_events):
    mock_table = MagicMock()
    mock_table.update_item.side_effect = _client_error("InternalServerError")
    mock_dynamo.Table.return_value = mock_table

    with pytest.raises(ClientError):
        handler.lambda_handler({"detail": BASE_ORDER}, {})
