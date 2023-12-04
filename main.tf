# Create a provider

provider "aws" {
   region     = var.region
}

# Provide module inpputs

module "VPC" {
  source = ".//module-1"
  vpc_cidr = "10.0.0.0/16"
  public_subnet_cidr = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidr = ["10.0.3.0/24", "10.0.4.0/24"]
  us_availability_zone = ["us-east-1a", "us-east-1b"]
  instance_type   = "t2.micro"
  tag             = "EC2 Public subnet 1"
  ami             = "ami-0fc5d935ebf8bc3bc"
}
