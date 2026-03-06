# -----------------------------------------------------------------------------
# Development Keycloak Server (EC2)
# NOTE: This is an insecure, ephemeral dev instance not suitable for production.
# -----------------------------------------------------------------------------

resource "aws_vpc" "keycloak_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-${var.environment}-keycloak-vpc"
  }
}

resource "aws_internet_gateway" "keycloak_igw" {
  vpc_id = aws_vpc.keycloak_vpc.id

  tags = {
    Name = "${var.project_name}-${var.environment}-keycloak-igw"
  }
}

resource "aws_subnet" "keycloak_subnet" {
  vpc_id                  = aws_vpc.keycloak_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-keycloak-subnet"
  }
}

resource "aws_route_table" "keycloak_rt" {
  vpc_id = aws_vpc.keycloak_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.keycloak_igw.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-keycloak-rt"
  }
}

resource "aws_route_table_association" "keycloak_rta" {
  subnet_id      = aws_subnet.keycloak_subnet.id
  route_table_id = aws_route_table.keycloak_rt.id
}

resource "aws_security_group" "keycloak_sg" {
  name        = "${var.project_name}-${var.environment}-keycloak-sg"
  description = "Allow inbound traffic for Keycloak Dev Server"
  vpc_id      = aws_vpc.keycloak_vpc.id

  ingress {
    description = "Keycloak HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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
    Name = "${var.project_name}-${var.environment}-keycloak-sg"
  }
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "keycloak" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.small"
  subnet_id     = aws_subnet.keycloak_subnet.id

  vpc_security_group_ids = [aws_security_group.keycloak_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y docker
              systemctl enable docker
              systemctl start docker
              
              # Run Keycloak in dev mode
              # Note: In production, use start instead of start-dev, configure a proper DB, and use HTTPS.
              docker run -d --name keycloak -p 8080:8080 \
                -e KEYCLOAK_ADMIN=admin \
                -e KEYCLOAK_ADMIN_PASSWORD=admin \
                quay.io/keycloak/keycloak:latest start-dev
              EOF

  tags = {
    Name = "${var.project_name}-${var.environment}-keycloak"
  }
}

output "keycloak_dev_url" {
  description = "The HTTP URL for the development Keycloak instance"
  value       = "http://${aws_instance.keycloak.public_ip}:8080"
}
