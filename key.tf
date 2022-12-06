
# ssh key for instance management
resource "tls_private_key" "ec2_key" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "deployer" {
  public_key = tls_private_key.ec2_key.public_key_openssh
}

resource "local_sensitive_file" "ec2_pem" {
    content  = tls_private_key.ec2_key.private_key_openssh
    filename = "keys/ec2.pem"
}


# rails secrets
resource "random_id" "rails_secret_key" {
  byte_length = 64
}

resource "random_id" "rails_otp_secret" {
  byte_length = 64
}