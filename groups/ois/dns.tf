data "aws_route53_zone" "ois" {
  name     = local.dns_zone
  vpc_id   = data.aws_vpc.heritage.id
}

resource "aws_route53_record" "ois" {
  zone_id = data.aws_route53_zone.ois.zone_id
  name    = "${var.service_subtype}.${var.service}"
  type    = "A"

  alias {
    name    = aws_lb.ois.dns_name
    zone_id = aws_lb.ois.zone_id

    evaluate_target_health = false
  }
}

resource "aws_route53_record" "instance" {
  count = var.instance_count

  zone_id = data.aws_route53_zone.ois.zone_id
  name    = "instance-${count.index + 1}.${var.service_subtype}.${var.service}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.ois[count.index].private_ip]
}
