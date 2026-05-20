import json
import os

import boto3

ses_client = boto3.client("ses", region_name="us-east-1")

SENDER_EMAIL = os.environ["SENDER_EMAIL"]

ITEM_NAMES = {
    "ITEM-001": "Wireless Headphones",
    "ITEM-002": "Mechanical Keyboard",
    "ITEM-003": "USB-C Hub",
    "ITEM-004": "HD Webcam",
    "ITEM-005": "LED Desk Lamp",
}

ITEM_PRICES = {
    "ITEM-001": "$99.99",
    "ITEM-002": "$149.99",
    "ITEM-003": "$49.99",
    "ITEM-004": "$79.99",
    "ITEM-005": "$59.99",
}


def lambda_handler(event, context):
    order = event["detail"]
    order_id = order["order_id"]
    customer_email = order["customer_email"]
    item_id = order["item_id"]
    quantity = order["quantity"]

    item_name = ITEM_NAMES.get(item_id, item_id)
    item_price = ITEM_PRICES.get(item_id, "N/A")
    short_id = order_id[:8].upper()

    body = (
        f"Hi,\n\n"
        f"Great news — your order has been confirmed and payment received!\n\n"
        f"Order ID:  {order_id}\n"
        f"Item:      {item_name}\n"
        f"Quantity:  {quantity}\n"
        f"Price:     {item_price} each\n\n"
        f"Payment reference: {order.get('payment_intent_id', 'N/A')}\n\n"
        f"Your order is now being processed for fulfillment.\n\n"
        f"Thanks for shopping with us!\n"
    )

    ses_client.send_email(
        Source=SENDER_EMAIL,
        Destination={"ToAddresses": [customer_email]},
        Message={
            "Subject": {"Data": f"Order {short_id} Confirmed"},
            "Body": {"Text": {"Data": body}},
        },
    )
