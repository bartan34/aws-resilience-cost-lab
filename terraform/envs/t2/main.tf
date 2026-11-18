locals {
  ecr_registry = "742752463962.dkr.ecr.eu-west-1.amazonaws.com"
  image        = "${local.ecr_registry}/ca2-app:323a9e2"
}

module "stack" {
  source = "../../modules/ha_stack"

  name         = "ca2-t2"
  tier         = "T2"
  az_ids       = ["euw1-az1", "euw1-az2"]
  multi_az     = true
  image        = local.image
  ecr_registry = local.ecr_registry
  ami_id       = "ami-01feb2929337f1f0f"
}

output "db_endpoint" {
  value = module.stack.db_endpoint
}

output "db_az" {
  value = module.stack.db_az
}

output "app_url" {
  value = module.stack.app_url
}

output "asg_name" {
  value = module.stack.asg_name
}