
resource "aws_ses_email_identity" "owner" {
  email = var.owner_email
}

resource "aws_ses_domain_identity" "email" {
  domain = var.domain
}

resource "aws_route53_record" "email_verification" {
  zone_id = aws_route53_zone.mastodon.zone_id
  name    = "_amazonses.${aws_route53_zone.mastodon.name}"
  type    = "TXT"
  ttl     = "600"
  records = [aws_ses_domain_identity.email.verification_token]
}

resource "aws_ses_domain_identity_verification" "email_verification" {
  domain = aws_ses_domain_identity.email.id

  depends_on = [aws_route53_record.email_verification]
}

resource "aws_ses_domain_dkim" "email" {
  domain = aws_ses_domain_identity.email.domain
}

# AWS can create these records for you, but this saves you a few clicks.
resource "aws_route53_record" "amazonses_dkim_record" {
  count   = 3
  zone_id = aws_route53_zone.mastodon.zone_id
  name    = "${aws_ses_domain_dkim.email.dkim_tokens[count.index]}._domainkey"
  type    = "CNAME"
  ttl     = "600"
  records = ["${aws_ses_domain_dkim.email.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

resource "aws_iam_policy" "send_email" {
  # name = "mastodon-send-email"
  policy = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Sid": "VisualEditor0",
              "Effect": "Allow",
              "Action": "ses:SendRawEmail",
              "Resource": "*"
          }
      ]
    }
  EOF
}

resource "aws_iam_user" "send_email" {
  name = "Mastodon-Send-Email"
}

resource "aws_iam_policy_attachment" "send_email" {
  name = "send_email"
  users      = [aws_iam_user.send_email.name]
  policy_arn = aws_iam_policy.send_email.arn
}

resource "aws_iam_access_key" "smtp_key" {
  user = aws_iam_user.send_email.name
}