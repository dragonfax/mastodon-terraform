provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Domain = var.domain
    }
  }
}

terraform {
  required_version = ">= 0.12.0"
}

