import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    for record in event["Records"]:
        # EventBridge delivers the full event as a JSON string inside the SNS Message field
        message = json.loads(record["Sns"]["Message"])
        order = message["detail"]

        fulfillment = {
            "event": "fulfillment_queued",
            "order_id": order["order_id"],
            "item_id": order["item_id"],
            "quantity": order["quantity"],
            "payment_intent_id": order.get("payment_intent_id"),
        }

        logger.info(json.dumps(fulfillment))
