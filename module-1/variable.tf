
variable "vpc_cidr" {
  type        = string
  description = "Public Subnet CIDR values"
}

variable "public_subnet_cidr" {
  type        = list(string)
  description = "Public Subnet CIDR values"
}

variable "private_subnet_cidr" {
  type        = list(string)
  description = "Private Subnet CIDR values"
}

variable "us_availability_zone" {
  type        = list(string)
  description = "Availability Zones"
}

variable "instance_type" {
  type = string
  description = "Type of EC2 instance"
}

variable "ami" {
  type        = string
  description = "AMI Image ID"
}

variable "tag" {
  type = string
  description = "Tag for EC2 instance"
  default = " HelloWorld"
}