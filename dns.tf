resource "aws_route53_zone" "mastodon" {
  name = "${var.domain}."
}

resource "aws_route53_record" "mastodon_hostname" {
  zone_id = aws_route53_zone.mastodon.zone_id
  name    = aws_route53_zone.mastodon.name
  type    = "A"
  ttl     = 10
  records = [aws_instance.mastodon.public_ip]
}
