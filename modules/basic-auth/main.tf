data "aws_iam_policy_document" "assume_role_policy_lambda" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "assume_role_policy_authorizer" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "role_policy_lambda" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "secretsmanager:GetSecretValue",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "role_policy_authorizer" {
  statement {
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "${var.unique_name}-lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy_lambda.json
}

resource "aws_iam_role_policy" "role_policy_lambda" {
  name   = "${var.unique_name}-role-policy-lambda"
  policy = data.aws_iam_policy_document.role_policy_lambda.json
  role   = aws_iam_role.iam_for_lambda.id
}

resource "aws_iam_role" "iam_for_authorizer" {
  name               = "${var.unique_name}-authorizer"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy_authorizer.json
}

resource "aws_iam_role_policy" "role_policy_authorizer" {
  name   = "${var.unique_name}-role-policy-authorizer"
  policy = data.aws_iam_policy_document.role_policy_authorizer.json
  role   = aws_iam_role.iam_for_authorizer.id
}


/* basic authorizer */
resource "aws_apigatewayv2_authorizer" "basic" {
  api_id                            = var.api_id
  authorizer_type                   = "REQUEST"
  authorizer_credentials_arn        = aws_iam_role.iam_for_authorizer.arn
  authorizer_uri                    = aws_lambda_function.basic_auth.invoke_arn
  authorizer_payload_format_version = "2.0"
  enable_simple_responses           = true
  identity_sources                  = ["$request.header.authorization"]
  name                              = "${var.unique_name}-authorizer"
}

data "archive_file" "authorizer" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/authorizer"
  output_path = "${path.module}/authorizer.zip"
}

data "archive_file" "start" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/start"
  output_path = "${path.module}/start.zip"
}


/* lambda function */
resource "aws_lambda_function" "basic_auth" {
  filename         = data.archive_file.authorizer.output_path
  function_name    = "${var.unique_name}-basic-auth"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "function.lambda_handler"
  runtime          = "python3.8"
  source_code_hash = data.archive_file.authorizer.output_base64sha256
  environment {
    variables = {
      SECRET_ID = var.secret_id
    }
  }
}

resource "aws_lambda_function" "start" {
  filename         = data.archive_file.start.output_path
  function_name    = "${var.unique_name}-basic-start"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "function.lambda_handler"
  runtime          = "python3.8"
  source_code_hash = data.archive_file.start.output_base64sha256
}

/* basic auth request startpoint */
resource "aws_apigatewayv2_route" "start" {
  api_id             = var.api_id
  operation_name     = "ConnectRoute"
  target             = "integrations/${aws_apigatewayv2_integration.start.id}"
  route_key          = "GET /auth/{proxy+}"
  authorization_type = "NONE"
}

resource "aws_apigatewayv2_route" "start2" {
  api_id             = var.api_id
  operation_name     = "ConnectRoute"
  target             = "integrations/${aws_apigatewayv2_integration.start.id}"
  route_key          = "GET /auth"
  authorization_type = "NONE"
}

resource "aws_apigatewayv2_integration" "start" {
  api_id                 = var.api_id
  integration_type       = "AWS_PROXY"
  credentials_arn        = aws_iam_role.iam_for_authorizer.arn
  connection_type        = "INTERNET"
  description            = "Authentication startpoint"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.start.invoke_arn
  payload_format_version = "2.0"
}

