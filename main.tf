
# Terraform EC2 + Nginx in Two AWS Regions


terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}


# Variables


variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "public_key" {
  description = "Your public SSH key content"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR range allowed for SSH"
  type        = string
  default     = "0.0.0.0/0"
}


# Providers — one per region


provider "aws" {
  alias  = "east"
  region = "us-east-1"
}

provider "aws" {
  alias  = "west"
  region = "us-west-2"
}
# Key pairs


resource "aws_key_pair" "east_key" {
  provider   = aws.east
  key_name   = "tf-key-us-east-1"
  public_key = var.public_key
}

resource "aws_key_pair" "west_key" {
  provider   = aws.west
  key_name   = "tf-key-us-west-2"
  public_key = var.public_key
}

# AMI lookups (Amazon Linux 2)


data "aws_ami" "east_ami" {
  provider    = aws.east
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

data "aws_ami" "west_ami" {
  provider    = aws.west
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}


# Security Groups


resource "aws_security_group" "east_sg" {
  provider    = aws.east
  name        = "allow_ssh_http-east"
  description = "Allow SSH and HTTP inbound"

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "east_sg"
  }
}

resource "aws_security_group" "west_sg" {
  provider    = aws.west
  name        = "allow_ssh_http-west"
  description = "Allow SSH and HTTP inbound"

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "west_sg"
  }
}

# EC2 Instances (with Nginx installation)


resource "aws_instance" "east_instance" {
  provider              = aws.east
  ami                   = data.aws_ami.east_ami.id
  instance_type         = var.instance_type
  key_name              = aws_key_pair.east_key.key_name
  vpc_security_group_ids = [aws_security_group.east_sg.id]

  # Install and start Nginx on startup
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install nginx1 -y
              systemctl enable nginx
              systemctl start nginx
              echo "<h1>Hello from us-east-1!</h1>" > /usr/share/nginx/html/index.html
              EOF

  tags = {
    Name   = "nginx-east-instance"
    Region = "us-east-1"
  }
}

resource "aws_instance" "west_instance" {
  provider              = aws.west
  ami                   = data.aws_ami.west_ami.id
  instance_type         = var.instance_type
  key_name              = aws_key_pair.west_key.key_name
  vpc_security_group_ids = [aws_security_group.west_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install nginx1 -y
              systemctl enable nginx
              systemctl start nginx
              echo "<h1>Hello from us-west-2!</h1>" > /usr/share/nginx/html/index.html
              EOF

  tags = {
    Name   = "nginx-west-instance"
    Region = "us-west-2"
  }
}


# Outputs


output "ec2_instances" {
  value = {
    us_east_1 = {
      instance_id = aws_instance.east_instance.id
      public_ip   = aws_instance.east_instance.public_ip
      public_dns  = aws_instance.east_instance.public_dns
    }
    us_west_2 = {
      instance_id = aws_instance.west_instance.id
      public_ip   = aws_instance.west_instance.public_ip
      public_dns  = aws_instance.west_instance.public_dns
    }
  }
  description = "Public IPs and DNS of EC2 instances in both regions"
}

