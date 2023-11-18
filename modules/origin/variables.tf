variable "name" {}
variable "ami" {
    default = ""
}
variable "private_subnets" {}
variable "public_subnets" {}
variable "image_url" {}
variable "security_group_id" {}
variable "vpc_id" {}
variable "private_cidr_blocks" {}
variable "whitelisted_ip" {}