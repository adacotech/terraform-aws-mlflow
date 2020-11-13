resource "aws_acm_certificate" "main_cert" {
  domain_name       = local.subdomain_fullname
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.unique_name}-main-ssl"
  }
}

resource "aws_route53_record" "main_cert_validation" {
  name    = tolist(aws_acm_certificate.main_cert.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.main_cert.domain_validation_options)[0].resource_record_type
  zone_id = data.aws_route53_zone.main_domain_zone.zone_id
  records = [tolist(aws_acm_certificate.main_cert.domain_validation_options)[0].resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "main_cert" {
  certificate_arn         = aws_acm_certificate.main_cert.arn
  validation_record_fqdns = [aws_route53_record.main_cert_validation.fqdn]
}

data "aws_route53_zone" "main_domain_zone" {
  zone_id = var.main_zone_id
}

resource "aws_route53_record" "main" {
  zone_id = data.aws_route53_zone.main_domain_zone.zone_id
  name    = local.subdomain_fullname
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.mlflow.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.mlflow.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}

