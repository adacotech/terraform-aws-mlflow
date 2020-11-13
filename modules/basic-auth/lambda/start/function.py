# -*- coding: utf-8

import json
import logging

logger = logging.getLogger()

def lambda_handler(event, context):
    logger.warn(event)
    if not "authorization" in [key.lower() for key in event["headers"].keys()]:
        return {
            "statusCode": "401",
            "headers": {
                "WWW-Authenticate": "Basic"
            }
        }
    return {
        "statusCode": "301",
        "headers": {
            "Location": f"https://{event['requestContext']['domainName']}/"
        }
    }

