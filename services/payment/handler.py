import json
import logging
import os
from datetime import datetime, timezone

import boto3
import stripe

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
events_client = boto3.client("events")

# Prices in cents — matches the valid item catalog in the validation Lambda
ITEM_PRICES_CENTS = {
    "ITEM-001": 9999,   # $99.99
    "ITEM-002": 14999,  # $149.99
    "ITEM-003": 4999,   # $49.99
    "ITEM-004": 7999,   # $79.99
    "ITEM-005": 5999,   # $59.99
}

# Cached across warm invocations to avoid a Secrets Manager call every time
_stripe_key_cache = None


def lambda_handler(event, context):
    order = event["detail"]
    order_id = order["order_id"]

    stripe.api_key = _get_stripe_key()
    amount_cents = ITEM_PRICES_CENTS.get(order["item_id"], 0) * order["quantity"]

    try:
        intent = stripe.PaymentIntent.create(
            amount=amount_cents,
            currency="usd",
            payment_method="pm_card_visa",
            confirm=True,
            automatic_payment_methods={"enabled": True, "allow_redirects": "never"},
            metadata={"order_id": order_id},
        )
        _update_order_status(order_id, "PAYMENT_CONFIRMED", payment_intent_id=intent.id)
        _publish_event("PaymentConfirmed", {**order, "payment_intent_id": intent.id})

    except stripe.error.CardError as e:
        logger.info(json.dumps({
            "event": "payment_failed",
            "order_id": order_id,
            "reason": e.user_message,
        }))
        _update_order_status(order_id, "PAYMENT_FAILED")
        _publish_event("PaymentFailed", {**order, "failure_reason": e.user_message})

    except stripe.error.StripeError as e:
        # Non-card errors (network, rate limit, API outage) — let Lambda retry
        raise RuntimeError(f"Stripe API error: {e}") from e


def _get_stripe_key():
    global _stripe_key_cache
    if _stripe_key_cache:
        return _stripe_key_cache

    secret_arn = os.environ.get("STRIPE_SECRET_ARN")
    if secret_arn:
        secrets_client = boto3.client("secretsmanager")
        _stripe_key_cache = secrets_client.get_secret_value(SecretId=secret_arn)["SecretString"]
    else:
        # Fallback for local testing — set STRIPE_SECRET_KEY directly
        _stripe_key_cache = os.environ["STRIPE_SECRET_KEY"]

    return _stripe_key_cache


def _update_order_status(order_id, status, payment_intent_id=None):
    table = dynamodb.Table(os.environ["ORDERS_TABLE"])
    update_expr = "SET #s = :status, updated_at = :now"
    attr_values = {
        ":status": status,
        ":now": datetime.now(timezone.utc).isoformat(),
    }
    if payment_intent_id:
        update_expr += ", payment_intent_id = :pi_id"
        attr_values[":pi_id"] = payment_intent_id

    table.update_item(
        Key={"order_id": order_id},
        UpdateExpression=update_expr,
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues=attr_values,
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
