# Terraform AWS Infrastriucture Workshop
# Created on Nov 5, 2022


terraform {
  required_version = ">= 1.5"
  backend "s3" {}
}


provider "aws" {
  region = var.region
}
