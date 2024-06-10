provider "aws" {
  region  = "us-east-1"
  profile = "cli"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.53.0"
    }
  }
}