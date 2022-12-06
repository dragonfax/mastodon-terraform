data "http" "home_broadband_ip" {
  url = "http://ipv4.icanhazip.com"
}

data "aws_availability_zone" mastodon {
  name = "${var.region}b"
}

resource "aws_vpc" "mastodon" {
  cidr_block = "10.0.0.0/16"
}

data "aws_route_table" "mastodon" {
    route_table_id = aws_vpc.mastodon.main_route_table_id
}

resource "aws_internet_gateway" "mastodon" {
  vpc_id = aws_vpc.mastodon.id
}

resource "aws_route" "mastodon_public" {
  route_table_id = data.aws_route_table.mastodon.id
  gateway_id = aws_internet_gateway.mastodon.id
  destination_cidr_block = "0.0.0.0/0"
}


resource "aws_subnet" "mastodon" {
  vpc_id            = aws_vpc.mastodon.id
  cidr_block        = aws_vpc.mastodon.cidr_block
  availability_zone = data.aws_availability_zone.mastodon.name
}


module "ssh_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "ssh"
  description = "Security group for ssh"
  vpc_id      = aws_vpc.mastodon.id

  ingress_cidr_blocks = ["${chomp(data.http.home_broadband_ip.response_body)}/32"]
  ingress_rules       = ["ssh-tcp"]
}

module "web_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "web"
  description = "Security group for web traffic"
  vpc_id      = aws_vpc.mastodon.id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp", "all-icmp"]
  egress_rules        = ["all-all"]
}

