module "subdomain1" {
  source         = "./modules/subdomain"
  main_zone_id   = var.main_zone_id
  subdomain_name = var.subdomain_name
  unique_name    = var.unique_name
}

module "basic-authorizer" {
  source      = "./modules/basic-auth"
  api_id      = aws_apigatewayv2_api.mlflow[0].id
  unique_name = var.unique_name
  secret_id   = var.secret_id
}

resource "aws_cloudwatch_log_group" "apigateway" {
  name              = "/aws/apigateway/${var.unique_name}"
  retention_in_days = var.service_log_retention_in_days
  tags              = local.tags
}

resource "aws_apigatewayv2_api" "mlflow" {
  count                        = var.main_zone_id != null ? 1 : 0
  name                         = "${var.unique_name}-api"
  protocol_type                = "HTTP"
  disable_execute_api_endpoint = true
}

resource "aws_apigatewayv2_stage" "mlflow" {
  count       = var.main_zone_id != null ? 1 : 0
  api_id      = aws_apigatewayv2_api.mlflow[0].id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigateway.arn
    format          = "$context.identity.sourceIp,$context.requestTime,$context.httpMethod,$context.routeKey,$context.protocol,$context.status,$context.responseLength,$context.requestId"
  }
}

resource "aws_apigatewayv2_integration" "mlflow" {
  count              = var.main_zone_id != null ? 1 : 0
  api_id             = aws_apigatewayv2_api.mlflow[0].id
  integration_type   = "HTTP_PROXY"
  connection_id      = aws_apigatewayv2_vpc_link.mlflow[0].id
  connection_type    = "VPC_LINK"
  integration_method = "ANY"
  integration_uri    = aws_lb_listener.mlflow.arn
}


resource "aws_apigatewayv2_route" "mlflow" {
  count              = var.main_zone_id != null ? 1 : 0
  api_id             = aws_apigatewayv2_api.mlflow[0].id
  operation_name     = "ConnectRoute"
  target             = "integrations/${aws_apigatewayv2_integration.mlflow[0].id}"
  route_key          = "$default"
  authorization_type = "CUSTOM"
  authorizer_id      = module.basic-authorizer.authorizer_id
}


resource "aws_apigatewayv2_api_mapping" "mlflow" {
  count       = var.main_zone_id != null ? 1 : 0
  api_id      = aws_apigatewayv2_api.mlflow[0].id
  domain_name = module.subdomain1.apigatewayv2_domain_id
  stage       = aws_apigatewayv2_stage.mlflow[0].id
}

resource "aws_apigatewayv2_vpc_link" "mlflow" {
  count              = var.main_zone_id != null ? 1 : 0
  name               = "${var.unique_name}-vpc-link"
  security_group_ids = []
  subnet_ids         = var.load_balancer_subnet_ids

  tags = var.tags
}

