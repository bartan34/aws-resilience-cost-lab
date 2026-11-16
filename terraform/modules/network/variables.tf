variable "name" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_ids" {
  description = "AZ IDs, one public subnet per AZ"
  type        = list(string)
}