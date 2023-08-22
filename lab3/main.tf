terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.13.1"
    }
  }
}

provider "aws" {
  # 작업공간(리전지정)/access_key/secret_key
  region	= "ap-northeast-1" # tokyo
}

variable "server_port" {
  description	=	"web server port"
  type		=	number
}

resource "aws_security_group" "instance" {
  name = "terraform-example-instance"
  vpc_id = "vpc-0a1b41d86813a6cd5"
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = var.server_port
    to_port = var.server_port
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_instance" "testlinux1" {
  ami = "ami-0ed99df77a82560e6"
  instance_type	= "t2.micro"
  key_name = "webtest"
  vpc_security_group_ids = [aws_security_group.instance.id] # 보안 그룹 연결
  subnet_id = "subnet-032a217f29fd162fa"

  user_data = <<-EOF
    #!/bin/bash
    echo "Hello, World" > index.html
    nohup busybox httpd -f -p ${var.server_port} &
    EOF

  tags = {
    Name = "testlinux1"
  }
}
output "public_ip" {
  value = aws_instance.testlinux1.public_ip
}
