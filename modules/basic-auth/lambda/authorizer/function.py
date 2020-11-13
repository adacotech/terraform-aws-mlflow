# -*- coding: utf-8

import boto3
import base64
import json
import os
import logging

logger = logging.getLogger()

def validate_auth(event, username, password):
    if len(event.get("identitySource")) == 0:
        return False
    authorization_token = event["identitySource"][0].replace("Basic ", "")
    encoded_secret = base64.b64encode(f"{username}:{password}".encode()).decode()
    return authorization_token == encoded_secret

def build_iam_policy(event, principalId):
    identifier, service, action, region, account_id, apigateway_arn = event["methodArn"].split(":")
    api_id, stage, *rest = apigateway_arn.split("/")

    return {
        "principalId": principalId,
        "policyDocument": {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Action": "execute-api:Invoke",
                    "Effect": "Allow",
                    "Resource": [f"${identifier}:${service}:${action}:${region}:${account_id}:${api_id}/${stage}/*/*"]
                }
            ]
        }
    }

def lambda_handler(event, context):
    try:
        client = boto3.client(service_name="secretsmanager")
        secret_id = os.environ["SECRET_ID"]  # values from secretsmanager
        get_secret_value_response = client.get_secret_value(SecretId=secret_id)
    except ClientError as e:
        logger.warn("client error")
        raise e
    else:
        logger.warn(event)
        secret = json.loads(get_secret_value_response["SecretString"])
        if validate_auth(event, secret["AUTH_USERNAME"], secret["AUTH_PASSWORD"]):
            logger.warn("auth success")
            return {"isAuthorized": True}
        else:
            logger.warn("auth failed")
            return {
                "isAuthorized": False,
                "context": {
                    "challenge": "Basic"
                }
            }

