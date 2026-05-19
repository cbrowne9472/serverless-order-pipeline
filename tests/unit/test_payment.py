import importlib.util
import json
import os
import sys
from unittest.mock import MagicMock, patch

import stripe as stripe_lib
import pytest

os.environ.setdefault("ORDERS_TABLE", "test-orders-table")
os.environ.setdefault("EVENT_BUS_NAME", "test-event-bus")
os.environ.setdefault("STRIPE_SECRET_KEY", "sk_test_fake")

_spec = importlib.util.spec_from_file_location(
    "payment_handler",
    os.path.join(os.path.dirname(__file__), "../../services/payment/handler.py"),
)
handler = importlib.util.module_from_spec(_spec)
sys.modules["payment_handler"] = handler
_spec.loader.exec_module(handler)


BASE_ORDER = {
    "order_id": "order-abc-123",
    "customer_email": "test@example.com",
    "item_id": "ITEM-001",
    "quantity": 1,
    "status": "INVENTORY_RESERVED",
    "shipping_address": {
        "line1": "123 Main St",
        "city": "Austin",
        "state": "TX",
        "zip": "78701",
        "country": "US",
    },
}


def _mock_intent(id="pi_test_123"):
    intent = MagicMock()
    intent.id = id
    return intent


# --- happy path ---

@patch("payment_handler.events_client")
@patch("payment_handler.dynamodb")
@patch("payment_handler.stripe")
def test_successful_payment_confirms_order(mock_stripe, mock_dynamo, mock_events):
    mock_stripe.PaymentIntent.create.return_value = _mock_intent()
    mock_dynamo.Table.return_value = MagicMock()
    mock_events.put_events.return_value = {"FailedEntryCount": 0, "Entries": [{}]}
    handler._stripe_key_cache = "sk_test_fake"

    handler.lambda_handler({"detail": BASE_ORDER}, {})

    update = mock_dynamo.Table.return_value.update_item.call_args[1]
    assert update["ExpressionAttributeValues"][":status"] == "PAYMENT_CONFIRMED"
    assert ":pi_id" in update["ExpressionAttributeValues"]


@patch("payment_handler.events_client")
@patch("payment_handler.dynamodb")
@patch("payment_handler.stripe")
def test_successful_payment_publishes_payment_confirmed(mock_stripe, mock_dynamo, mock_events):
    mock_stripe.PaymentIntent.create.return_value = _mock_intent("pi_test_456")
    mock_dynamo.Table.return_value = MagicMock()
    mock_events.put_events.return_value = {"FailedEntryCount": 0, "Entries": [{}]}
    handler._stripe_key_cache = "sk_test_fake"

    handler.lambda_handler({"detail": BASE_ORDER}, {})

    entry = mock_events.put_events.call_args[1]["Entries"][0]
    assert entry["DetailType"] == "PaymentConfirmed"
    detail = json.loads(entry["Detail"])
    assert detail["payment_intent_id"] == "pi_test_456"


@patch("payment_handler.events_client")
@patch("payment_handler.dynamodb")
@patch("payment_handler.stripe")
def test_correct_amount_sent_to_stripe(mock_stripe, mock_dynamo, mock_events):
    mock_stripe.PaymentIntent.create.return_value = _mock_intent()
    mock_dynamo.Table.return_value = MagicMock()
    mock_events.put_events.return_value = {"FailedEntryCount": 0, "Entries": [{}]}
    handler._stripe_key_cache = "sk_test_fake"

    order = {**BASE_ORDER, "item_id": "ITEM-001", "quantity": 3}
    handler.lambda_handler({"detail": order}, {})

    call_kwargs = mock_stripe.PaymentIntent.create.call_args[1]
    assert call_kwargs["amount"] == 9999 * 3  # $99.99 x 3
    assert call_kwargs["currency"] == "usd"


# --- card declined ---

@patch("payment_handler.events_client")
@patch("payment_handler.dynamodb")
@patch("payment_handler.stripe.PaymentIntent")
def test_card_error_sets_payment_failed(mock_pi, mock_dynamo, mock_events):
    err = stripe_lib.error.CardError("Your card was declined.", "param", "card_declined")
    mock_pi.create.side_effect = err
    mock_dynamo.Table.return_value = MagicMock()
    mock_events.put_events.return_value = {"FailedEntryCount": 0, "Entries": [{}]}
    handler._stripe_key_cache = "sk_test_fake"

    handler.lambda_handler({"detail": BASE_ORDER}, {})

    update = mock_dynamo.Table.return_value.update_item.call_args[1]
    assert update["ExpressionAttributeValues"][":status"] == "PAYMENT_FAILED"


@patch("payment_handler.events_client")
@patch("payment_handler.dynamodb")
@patch("payment_handler.stripe.PaymentIntent")
def test_card_error_publishes_payment_failed(mock_pi, mock_dynamo, mock_events):
    err = stripe_lib.error.CardError("Your card was declined.", "param", "card_declined")
    mock_pi.create.side_effect = err
    mock_dynamo.Table.return_value = MagicMock()
    mock_events.put_events.return_value = {"FailedEntryCount": 0, "Entries": [{}]}
    handler._stripe_key_cache = "sk_test_fake"

    handler.lambda_handler({"detail": BASE_ORDER}, {})

    entry = mock_events.put_events.call_args[1]["Entries"][0]
    assert entry["DetailType"] == "PaymentFailed"
    assert "failure_reason" in json.loads(entry["Detail"])


# --- stripe api errors should propagate so Lambda retries ---

@patch("payment_handler.stripe")
def test_stripe_api_error_propagates(mock_stripe):
    mock_stripe.error.CardError = Exception
    mock_stripe.error.StripeError = RuntimeError
    mock_stripe.PaymentIntent.create.side_effect = RuntimeError("API unavailable")
    handler._stripe_key_cache = "sk_test_fake"

    with pytest.raises(Exception):
        handler.lambda_handler({"detail": BASE_ORDER}, {})
