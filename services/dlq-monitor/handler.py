import json
import os

import boto3

sqs = boto3.client("sqs")

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Methods": "GET,OPTIONS",
}

QUEUE_URLS = {
    "stream-processor-dlq": os.environ["STREAM_PROCESSOR_DLQ_URL"],
    "validation-dlq": os.environ["VALIDATION_DLQ_URL"],
    "inventory-dlq": os.environ["INVENTORY_DLQ_URL"],
    "payment-dlq": os.environ["PAYMENT_DLQ_URL"],
    "notification-dlq": os.environ["NOTIFICATION_DLQ_URL"],
    "warehouse-dlq": os.environ["WAREHOUSE_DLQ_URL"],
}


def lambda_handler(event, context):
    if event.get("httpMethod") == "OPTIONS":
        return {"statusCode": 200, "headers": CORS_HEADERS, "body": ""}

    dlqs = []
    for name, url in QUEUE_URLS.items():
        response = sqs.get_queue_attributes(
            QueueUrl=url,
            AttributeNames=["ApproximateNumberOfMessages"],
        )
        depth = int(response["Attributes"].get("ApproximateNumberOfMessages", 0))
        dlqs.append({"name": name, "depth": depth})

    return {
        "statusCode": 200,
        "headers": CORS_HEADERS,
        "body": json.dumps({"dlqs": dlqs}),
    }
