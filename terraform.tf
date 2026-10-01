terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.2"

  backend "s3" {
    bucket = "test-bucket-pratik-99"
    key    = "terraform.tfstate"
    region = "us-east-2"
  }
}
