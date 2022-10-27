provider "aws" {
  region = "us-east-1"
}

resource "aws_key_pair" "key" {
  key_name   = "key"
  public_key = file("class_key.pem.pub")
}


resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "Main VPC"
  }

}

resource "aws_subnet" "subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.10.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    "Name" = "Subnet 1 - us-east-1a"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    "Name" = "Gateway Main"
  }
}


resource "aws_route_table" "r" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

}

resource "aws_route_table_association" "table_subnet" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.r.id

}

resource "aws_security_group" "sg-1" {
  name        = "sg_ping_ssh "
  vpc_id      = aws_vpc.main.id
  description = "Permitir ping y SSH"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "Ping y SSH"
  }
}

resource "aws_security_group" "sg-2" {
  name        = "sg_http "
  vpc_id      = aws_vpc.main.id
  description = "Permitir HTTP y HTTPS"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "HTTP y HTTPS"
  }
}


resource "aws_instance" "server2" {
  ami                         = "ami-08c40ec9ead489470"
  instance_type               = "t2.micro"
  count                       = 1
  associate_public_ip_address = true
  subnet_id              = aws_subnet.subnet.id
  vpc_security_group_ids = [aws_security_group.sg-1.id, aws_security_group.sg-2.id]
  private_ip             = "10.0.10.11"
  key_name               = aws_key_pair.key.id
  user_data = <<EOF
#!/bin/bash
sudo apt update
sudo apt install -y git
sudo git clone https://github.com/espineldago/TF_SOD.git
cd TF_SOD
sudo apt install -y docker.io
sudo docker build -t sod .
sudo docker run -d -p 80:80 sod
EOF

  tags = {
    Name  = "server"
    Owner = "terraform"
  }
}


