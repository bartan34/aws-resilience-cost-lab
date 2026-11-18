terraform {
  required_version = "~> 1.16"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "s3" {
    bucket       = "ca2-tfstate-742752463962"
    key          = "t2/terraform.tfstate"
    region       = "eu-west-1"
    profile      = "ca2"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region              = "eu-west-1"
  profile             = "ca2"
  allowed_account_ids = ["742752463962"]

  default_tags {
    tags = {
      Project = "CA2"
      Tier    = "T2"
      Repo    = "bartan34/aws-resilience-cost-lab"
    }
  }
}