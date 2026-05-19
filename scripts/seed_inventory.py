"""
Populate the inventory table with test items.

Usage:
    python scripts/seed_inventory.py --table <table-name> [--region us-east-1]

The table name is printed by:
    terraform -chdir=terraform/environments/dev output -raw inventory_table_name
"""

import argparse
import boto3

ITEMS = [
    {"item_id": "ITEM-001", "item_name": "Wireless Headphones", "quantity": 100},
    {"item_id": "ITEM-002", "item_name": "Mechanical Keyboard",  "quantity": 50},
    {"item_id": "ITEM-003", "item_name": "USB-C Hub",            "quantity": 200},
    {"item_id": "ITEM-004", "item_name": "Webcam 4K",            "quantity": 30},
    {"item_id": "ITEM-005", "item_name": "Monitor Stand",        "quantity": 75},
]


def seed(table_name, region):
    dynamodb = boto3.resource("dynamodb", region_name=region)
    table = dynamodb.Table(table_name)

    with table.batch_writer() as batch:
        for item in ITEMS:
            batch.put_item(Item=item)
            print(f"  seeded {item['item_id']} — {item['item_name']} (qty: {item['quantity']})")

    print(f"\nSeeded {len(ITEMS)} items into {table_name}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--table",  required=True, help="DynamoDB inventory table name")
    parser.add_argument("--region", default="us-east-1")
    args = parser.parse_args()
    seed(args.table, args.region)
