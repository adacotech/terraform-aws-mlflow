resource "aws_acm_certificate" "main_cert" {
  domain_name       = "${var.subdomain_name}.${data.aws_route53_zone.main_domain_zone[0].name}"
  validation_method = "DNS"
  count             = var.main_zone_id != null ? 1 : 0

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.unique_name}-main-ssl"
  }
}

resource "aws_route53_record" "main_cert_validation" {
  name    = tolist(aws_acm_certificate.main_cert[0].domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.main_cert[0].domain_validation_options)[0].resource_record_type
  zone_id = data.aws_route53_zone.main_domain_zone[0].zone_id
  records = [tolist(aws_acm_certificate.main_cert[0].domain_validation_options)[0].resource_record_value]
  ttl     = 60
  count   = var.main_zone_id != null ? 1 : 0
}

resource "aws_acm_certificate_validation" "main_cert" {
  count                   = var.main_zone_id != null ? 1 : 0
  certificate_arn         = aws_acm_certificate.main_cert[0].arn
  validation_record_fqdns = [aws_route53_record.main_cert_validation[0].fqdn]
}

data "aws_route53_zone" "main_domain_zone" {
  zone_id = var.main_zone_id
  count   = var.main_zone_id != null ? 1 : 0
}

resource "aws_route53_record" "main" {
  zone_id = data.aws_route53_zone.main_domain_zone[0].zone_id
  name    = aws_apigatewayv2_domain_name.mlflow[0].domain_name
  type    = "A"
  count   = var.main_zone_id != null ? 1 : 0

  alias {
    name                   = aws_apigatewayv2_domain_name.mlflow[0].domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.mlflow[0].domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_cloudwatch_log_group" "apigateway" {
  name              = "/aws/apigateway/${var.unique_name}"
  retention_in_days = var.service_log_retention_in_days
  tags              = local.tags
}


resource "aws_apigatewayv2_domain_name" "mlflow" {
  domain_name = "${var.subdomain_name}.${data.aws_route53_zone.main_domain_zone[0].name}"
  count       = var.main_zone_id != null ? 1 : 0

  domain_name_configuration {
    certificate_arn = aws_acm_certificate.main_cert[0].arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
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
    format = "$context.identity.sourceIp,$context.requestTime,$context.httpMethod,$context.routeKey,$context.protocol,$context.status,$context.responseLength,$context.requestId"
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
  count          = var.main_zone_id != null ? 1 : 0
  api_id         = aws_apigatewayv2_api.mlflow[0].id
  operation_name = "ConnectRoute"
  target         = "integrations/${aws_apigatewayv2_integration.mlflow[0].id}"
  route_key      = "$default"
}


resource "aws_apigatewayv2_api_mapping" "mlflow" {
  count       = var.main_zone_id != null ? 1 : 0
  api_id      = aws_apigatewayv2_api.mlflow[0].id
  domain_name = aws_apigatewayv2_domain_name.mlflow[0].id
  stage       = aws_apigatewayv2_stage.mlflow[0].id
}

resource "aws_apigatewayv2_vpc_link" "mlflow" {
  count              = var.main_zone_id != null ? 1 : 0
  name               = "${var.unique_name}-vpc-link"
  security_group_ids = []
  subnet_ids         = var.load_balancer_subnet_ids

  tags = var.tags
}

