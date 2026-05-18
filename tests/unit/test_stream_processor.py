import importlib.util
import json
import os
from unittest.mock import MagicMock, patch

import pytest

os.environ["EVENT_BUS_NAME"] = "test-event-bus"

import sys

_spec = importlib.util.spec_from_file_location(
    "stream_processor_handler",
    os.path.join(os.path.dirname(__file__), "../../services/stream-processor/handler.py"),
)
handler = importlib.util.module_from_spec(_spec)
sys.modules["stream_processor_handler"] = handler
_spec.loader.exec_module(handler)


def _make_record(new_image, event_name="INSERT", sequence_number="001"):
    return {
        "eventName": event_name,
        "dynamodb": {
            "SequenceNumber": sequence_number,
            "NewImage": new_image,
        },
    }


SAMPLE_IMAGE = {
    "order_id":       {"S": "abc-123"},
    "status":         {"S": "PENDING"},
    "customer_email": {"S": "test@example.com"},
    "item_id":        {"S": "ITEM-001"},
    "quantity":       {"N": "2"},
    "created_at":     {"S": "2024-01-01T00:00:00+00:00"},
    "updated_at":     {"S": "2024-01-01T00:00:00+00:00"},
    "shipping_address": {
        "M": {
            "line1":   {"S": "123 Main St"},
            "city":    {"S": "Austin"},
            "state":   {"S": "TX"},
            "zip":     {"S": "78701"},
            "country": {"S": "US"},
        }
    },
}


# --- happy path ---

@patch("stream_processor_handler.events_client")
def test_insert_publishes_order_created_event(mock_events):
    mock_events.put_events.return_value = {"FailedEntryCount": 0, "Entries": [{"EventId": "e1"}]}

    result = handler.lambda_handler({"Records": [_make_record(SAMPLE_IMAGE)]}, {})

    assert result == {"batchItemFailures": []}
    mock_events.put_events.assert_called_once()

    call_args = mock_events.put_events.call_args[1]["Entries"][0]
    assert call_args["DetailType"] == "OrderCreated"
    assert call_args["Source"] == "order-pipeline"
    assert call_args["EventBusName"] == "test-event-bus"

    detail = json.loads(call_args["Detail"])
    assert detail["order_id"] == "abc-123"
    assert detail["status"] == "PENDING"
    assert detail["quantity"] == 2


@patch("stream_processor_handler.events_client")
def test_non_insert_records_are_skipped(mock_events):
    record = _make_record(SAMPLE_IMAGE, event_name="MODIFY")
    result = handler.lambda_handler({"Records": [record]}, {})

    assert result == {"batchItemFailures": []}
    mock_events.put_events.assert_not_called()


@patch("stream_processor_handler.events_client")
def test_empty_records_returns_no_failures(mock_events):
    result = handler.lambda_handler({"Records": []}, {})
    assert result == {"batchItemFailures": []}


# --- failure handling ---

@patch("stream_processor_handler.events_client")
def test_eventbridge_failure_reported_as_batch_item_failure(mock_events):
    mock_events.put_events.return_value = {
        "FailedEntryCount": 1,
        "Entries": [{"ErrorCode": "InternalFailure", "ErrorMessage": "oops"}],
    }

    record = _make_record(SAMPLE_IMAGE, sequence_number="seq-999")
    result = handler.lambda_handler({"Records": [record]}, {})

    assert len(result["batchItemFailures"]) == 1
    assert result["batchItemFailures"][0]["itemIdentifier"] == "seq-999"


# --- deserialization ---

def test_deserialize_handles_nested_map():
    result = handler._deserialize(SAMPLE_IMAGE)  # noqa: SLF001
    assert result["order_id"] == "abc-123"
    assert result["quantity"] == 2
    assert result["shipping_address"]["city"] == "Austin"
