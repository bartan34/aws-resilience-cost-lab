module "network" {
  source = "../../modules/network"

  name   = "ca2-t0"
  az_ids = ["euw1-az1"]
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "subnet_ids" {
  value = module.network.subnet_ids
}