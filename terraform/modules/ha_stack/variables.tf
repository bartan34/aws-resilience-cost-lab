variable "name" {
  type = string
}

variable "tier" {
  type = string
}

variable "az_ids" {
  description = "Two AZ IDs for the app and database subnets"
  type        = list(string)
}

variable "multi_az" {
  description = "false = RDS Single-AZ (T1), true = RDS Multi-AZ (T2)"
  type        = bool
}

variable "image" {
  type = string
}

variable "ecr_registry" {
  type = string
}

variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "instance_type" {
  type    = string
  default = "t4g.small"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.small"
}