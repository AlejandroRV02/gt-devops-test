resource "aws_route53_zone" "main" {
  name = var.zone_name
}

resource "aws_acm_certificate" "cert" {
  domain_name       = var.zone_name
  validation_method = "DNS"

  subject_alternative_names = ["www.${var.zone_name}"]

  tags = var.tags
}

resource "aws_route53_record" "cert_validation" {
  count = length(aws_acm_certificate.cert.domain_validation_options)

  zone_id = aws_route53_zone.main.zone_id
  name    = aws_acm_certificate.cert.domain_validation_options[count.index].resource_record_name
  type    = aws_acm_certificate.cert.domain_validation_options[count.index].resource_record_type
  ttl     = 60
  records = [aws_acm_certificate.cert.domain_validation_options[count.index].resource_record_value]
}

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn          = aws_acm_certificate.cert.arn
  validation_record_fqdns  = aws_route53_record.cert_validation[*].fqdn
}
