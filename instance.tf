data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-*-hvm-*-arm64-gp2"]
  }
}

resource "aws_instance" "mastodon" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t4g.medium"
  associate_public_ip_address = true
  vpc_security_group_ids      = [module.ssh_sg.security_group_id, module.web_sg.security_group_id]
  subnet_id                   = aws_subnet.mastodon.id
  key_name                    = aws_key_pair.deployer.id
  availability_zone           = data.aws_availability_zone.mastodon.name

  credit_specification        {
    cpu_credits = "standard"
  }

  root_block_device {
    delete_on_termination = true
    encrypted             = false
    volume_size           = 10
    volume_type           = "gp3"

    # doesn't get default_tags, for some reason
    tags = {
      Domain = var.domain
    }
  }

  user_data_base64 = data.template_cloudinit_config.files.rendered

  monitoring = true
  ebs_optimized = true
  depends_on = [aws_internet_gateway.mastodon]

}
