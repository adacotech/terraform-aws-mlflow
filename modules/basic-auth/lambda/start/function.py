# -*- coding: utf-8

import boto3
import base64
import json
import os
import logging

logger = logging.getLogger()

def get_authorization_header(event):
    lower_headers = {key.lower(): val for key, val in event["headers"].items()}
    return lower_headers.get("authorization")

def validate_auth(authorization_token, username, password):
    if len(authorization_token) == 0:
        return False
    authorization_token = authorization_token.replace("Basic ", "")
    encoded_secret = base64.b64encode(f"{username}:{password}".encode()).decode()
    return authorization_token == encoded_secret

def lambda_handler(event, context):
    try:
        client = boto3.client(service_name="secretsmanager")
        secret_id = os.environ["SECRET_ID"]  # values from secretsmanager
        get_secret_value_response = client.get_secret_value(SecretId=secret_id)
    except ClientError as e:
        logger.warn("client error")
        raise e
    else:
        secret = json.loads(get_secret_value_response["SecretString"])
        if validate_auth(get_authorization_header(event), secret["AUTH_USERNAME"], secret["AUTH_PASSWORD"]):
            logger.warn("auth success")
            return {
                "statusCode": "302",
                "headers": {
                    "Location": f"https://{event['requestContext']['domainName']}/"
                }
            }
        else:
            logger.warn("auth failed")
            return {
                "statusCode": "401",
                "headers": {
                    "WWW-Authenticate": "Basic"
                }
            }

