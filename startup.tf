
locals {
  cloud_config = <<-EOT
    #cloud-config
    ${yamlencode({

      # We override several cloud-init modules to run on every boot
      # So that any changes from `terraform apply` are applied.
      cloud_init_modules = [
        "migrator",
        "bootcmd",
        [ "write-files", "always" ], # force config files to rewrite on every boot
        "write-metadata",
        "amazonlinux_repo_https",
        "growpart",
        "resizefs",
        "set-hostname",
        "update-hostname",
        "update-etc-hosts",
        "rsyslog",
        "users-groups",
        "ssh",
        "resolv-conf"
      ]

      cloud_final_modules = [
        "scripts-per-once",
        "scripts-per-boot",
        "scripts-per-instance",
        [ "scripts-user", "always" ], # force linux.sh to run on every boot
        "ssh-authkey-fingerprints",
        "keys-to-console",
        "phone-home",
        "final-message",
        "power-state-change"
      ]

      # config files to upload to the instance
      write_files = [
        {
          path = "/opt/docker-compose.yml"
          content = base64encode(templatefile("templates/docker-compose.yml",{
            domain = var.domain
          }))
          encoding = "b64"
          owner = "root:root"
          permissions = "0644"
        },
        {
          path = "/opt/nginx.mastodon.conf"
          content = base64encode(templatefile("templates/nginx.mastodon.conf",{
            domain = var.domain
          }))
          encoding = "b64"
          owner = "root:root"
          permissions = "0644"
        },
        {
          path = "/opt/.env.production"
          content = base64encode(templatefile("templates/env.production", { 
            smtp_login = aws_iam_access_key.smtp_key.id, 
            smtp_password = aws_iam_access_key.smtp_key.ses_smtp_password_v4, 
            s3_access_key = aws_iam_access_key.s3_key.id, 
            s3_secret_key = aws_iam_access_key.s3_key.secret, 
            domain = var.domain,
            bucket = var.bucket_name,
            region = var.region,
            rails_secret_key = random_id.rails_secret_key.hex,
            rails_otp_secret = random_id.rails_otp_secret.hex
          }))
          encoding = "b64"
          owner = "root:root"
          permissions = "0644"
        },
      ]
    })}
  EOT
}

# Note: you must have all the files to upload in one "write_files" doc.
# you can't have multiple "write_files" parts in a user_data multi-part cloud-init 
data "template_cloudinit_config" "files" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "cloud_config"
    content_type = "text/cloud-config"
    content      = local.cloud_config
  }

  part {
    filename     = "linux.sh"
    content_type = "text/x-shellscript"
    content      = templatefile("templates/linux.sh", {
      domain = var.domain,
      owner_email = var.owner_email
    })
  }

}