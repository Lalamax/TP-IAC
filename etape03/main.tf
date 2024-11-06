# Configure the AWS Provider
provider "aws" {
  region = "eu-west-3"
}

# Data source to get the latest Ubuntu 24.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["*ubuntu-*24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Create a security group for SSH
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"

  ingress {
    description = "SSH from anywhere"
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
    Name = "allow_ssh"
  }
}

# Create a security group for HTTP/HTTPS
resource "aws_security_group" "allow_http_s" {
  name        = "allow_http_s"
  description = "Allow HTTP/S inbound traffic"

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
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
    Name = "allow_http_s"
  }
}

# Create an EC2 instance for HTTP
resource "aws_instance" "http_instance" {
  ami                    = data.aws_ami.ubuntu.id
  key_name               = "myKey"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.allow_ssh.id, aws_security_group.allow_http_s.id]

  tags = {
    Name = "http-instance"
  }
}

# Create an EC2 instance for SCRIPT
resource "aws_instance" "script_instance" {
  ami                    = data.aws_ami.ubuntu.id
  key_name               = "myKey"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  tags = {
    Name = "script-instance"
  }
}

# Output the public IP of the HTTP instance
output "http_instance_public_ip" {
  value = aws_instance.http_instance.public_ip
}

# Output the public IP of the SCRIPT instance
output "script_instance_public_ip" {
  value = aws_instance.script_instance.public_ip
}
