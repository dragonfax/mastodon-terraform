
resource "aws_ebs_volume" "persistence" {
  availability_zone = data.aws_availability_zone.mastodon.name
  size = 10

  tags = {
    Persistent = "${var.domain}"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_volume_attachment" "persistence" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.persistence.id
  instance_id = aws_instance.mastodon.id
}

resource "aws_s3_bucket" "file_storage" {
  bucket = var.bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_acl" "private" {
  bucket = aws_s3_bucket.file_storage.id

  acl = "private"
}

resource "aws_s3_bucket_public_access_block" "can_be_public" {
  bucket = aws_s3_bucket.file_storage.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

}

resource "aws_s3_bucket_ownership_controls" "owner_preferred" {
  bucket = aws_s3_bucket.file_storage.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_iam_policy" "s3_access" {
  name = "${var.bucket_name}-s3-access"
  policy = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": "s3:*",
              "Resource": [
                  "arn:aws:s3:::${aws_s3_bucket.file_storage.id}",
                  "arn:aws:s3:::${aws_s3_bucket.file_storage.id}/*"
              ]
          }
      ]
    }
  EOF
}

resource "aws_iam_user" "s3_access" {
  name = "Mastodon-S3-Access"
}

resource "aws_iam_policy_attachment" "s3_access" {
  name = "s3_access"
  users      = [aws_iam_user.s3_access.name]
  policy_arn = aws_iam_policy.s3_access.arn
}

resource "aws_iam_access_key" "s3_key" {
  user = aws_iam_user.s3_access.name
}


## Backup of the persistent volume

resource "aws_iam_role" "dlm_lifecycle_role" {
  name = "dlm-lifecycle-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "dlm.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "dlm_lifecycle" {
  name = "dlm-lifecycle-policy"
  role = aws_iam_role.dlm_lifecycle_role.id

  policy = <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
      {
         "Effect": "Allow",
         "Action": [
            "ec2:CreateSnapshot",
            "ec2:CreateSnapshots",
            "ec2:DeleteSnapshot",
            "ec2:DescribeInstances",
            "ec2:DescribeVolumes",
            "ec2:DescribeSnapshots"
         ],
         "Resource": "*"
      },
      {
         "Effect": "Allow",
         "Action": [
            "ec2:CreateTags"
         ],
         "Resource": "arn:aws:ec2:*::snapshot/*"
      }
   ]
}
EOF
}

resource "aws_dlm_lifecycle_policy" "example" {
  description        = "1 weeks of daily snapshots"
  execution_role_arn = aws_iam_role.dlm_lifecycle_role.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    schedule {
      name = "daily"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["23:45"]
      }

      retain_rule {
        count = 7
      }

      copy_tags = true
    }

    target_tags = {
      Persistent = "${var.domain}"
    }
  }
}
