terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  alias = "default"
  region = var.aws_default_region
  access_key =  "<YOUR_AWS_ACCESS_KEY>"
  secret_key = "<YOUR_AWS_SECRET_KEY>"
}

provider "aws" {
  alias  = "east"
  region = "us-east-1"
  access_key = "<YOUR_AWS_ACCESS_KEY>"
  secret_key = "<YOUR_AWS_SECRET_KEY>"
}



