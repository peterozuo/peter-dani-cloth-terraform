import json
import boto3
import uuid
import os

dynamodb = boto3.resource("dynamodb")

table = dynamodb.Table(
    os.environ["TABLE_NAME"]
)

def lambda_handler(event, context):

    item_id = str(uuid.uuid4())

    table.put_item(
        Item={
            "id": item_id,
            "message": "Hello from Peter Dani Cloth!"
        }
    )

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps({
            "message": "Data successfully saved to DynamoDB!",
            "id": item_id
        })
    }