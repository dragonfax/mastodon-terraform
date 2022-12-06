variable "domain" {
  type = string
}

variable "owner_email" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "region" {
  type = string
}

variable "email_verify" {
  type = bool
  default = false
}