terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
locals {
  staging_env = "staging"
}
# Create a VPC 
resource "aws_vpc" "stagingVPC" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "${local.staging_env}-vpc-tag"
  }
}

# Create Public Subnets
resource "aws_subnet" "staging_public_subnets" {
  vpc_id = aws_vpc.stagingVPC.id
  count = length(var.public_subnet_cidr) #determines the length of list,map, or string
  cidr_block = element(var.public_subnet_cidr, count.index)
# element retrieves single element from the list- it is zero based
  availability_zone = element(var.us_availability_zone, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "${local.staging_env}-Public Subnet-tag ${count.index +1}"
  }
  
}

# Create Private Subnets
resource "aws_subnet" "staging_private_subnets" {
  vpc_id = aws_vpc.stagingVPC.id
  count = length(var.private_subnet_cidr) #determines the lengthe of list,map, or string
  cidr_block = element(var.private_subnet_cidr, count.index)
# element retrieves single element from the list; It is zero based
  availability_zone = element(var.us_availability_zone, count.index)

  tags = {
    Name = "${local.staging_env}-Private Subnet-tag ${count.index +1}"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "public_internet_gateway" {
  vpc_id = aws_vpc.stagingVPC.id
  tags = {
    Name = " IGW "
  }
}

# Create NAT Gateway
resource "aws_eip" "nat_eip" {
  count = length(var.private_subnet_cidr)
}

resource "aws_nat_gateway" "nat_gateway" {
  count      = length(var.private_subnet_cidr)
  depends_on = [aws_eip.nat_eip]
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id = aws_subnet.staging_private_subnets[count.index].id
  tags = {
    "Name" = " Private NAT GW "
  }
}

# Creating Public Subnet Route Tables
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.stagingVPC.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public_internet_gateway.id
  }
  tags = {
    Name = " RT Public "
  }
}

# Creating Private Subnet Route Tables
resource "aws_route_table" "private_route_table" {
  count      = length(var.private_subnet_cidr)
  vpc_id = aws_vpc.stagingVPC.id
  depends_on = [aws_nat_gateway.nat_gateway]
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway[count.index].id
  }
  
  tags = {
    Name = " RT Private "
  }
}

# Create route table and subnet association
resource "aws_route_table_association" "public_subnet_asso" {
  count = length(var.public_subnet_cidr)
  depends_on = [aws_subnet.staging_public_subnets, aws_route_table.public_route_table]
  subnet_id      = element(aws_subnet.staging_public_subnets[*].id, count.index)
  route_table_id = aws_route_table.public_route_table.id
}


resource "aws_route_table_association" "private_subnet_asso" {
  count = length(var.private_subnet_cidr)
  depends_on = [aws_subnet.staging_private_subnets, aws_route_table.private_route_table]
  subnet_id      = element(aws_subnet.staging_private_subnets[*].id, count.index)
  route_table_id = aws_route_table.private_route_table[count.index].id
}

# Creating Security Group
resource "aws_security_group" "staging_sg" {
  egress = [
    {
      cidr_blocks      = [ "0.0.0.0/0", ]
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = false
      to_port          = 0
    }
  ]
  ingress                = [
    {
      cidr_blocks      = [ "0.0.0.0/0", ]
      description      = ""
      from_port        = 22
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = 22
    }
  ]
  vpc_id = aws_vpc.stagingVPC.id
  depends_on = [aws_vpc.stagingVPC]
  tags = {
    Name = "SG : stagingVPC "
  }
}


# Create an EC2 instance

data "aws_subnet" "public" {
  
  vpc_id = aws_vpc.stagingVPC.id
  filter {
    name = "tag:Name"
    values = ["staging-Public Subnet-tag 1"]
  }

  depends_on = [
    aws_route_table_association.public_subnet_asso
  ]
}

resource "aws_instance" "ec2_instance" {
    
    ami = var.ami
    instance_type = var.instance_type
    key_name= "ec2-test-ssh-keypair" # add your aws keypair here
    subnet_id = data.aws_subnet.public.id
    vpc_security_group_ids = [aws_security_group.staging_sg.id]
    tags = {
       Name = var.tag
    }
    user_data = <<-EOF
      #!/bin/sh
      sudo apt-get update
      sudo apt install -y apache2
      sudo systemctl status apache2
      sudo systemctl start apache2
      sudo chown -R $USER:$USER /var/www/html
      sudo echo "<html><body><h1>Hello this is module-2 at instance id `curl http://169.254.169.254/latest/meta-data/instance-id` </h1></body></html>" > /var/www/html/index.html
      EOF
} 

# Adding oupput blocks. Delete if they don't work.
output "pub_sub_id" {
  value = aws_subnet.staging_public_subnets.*.id
}