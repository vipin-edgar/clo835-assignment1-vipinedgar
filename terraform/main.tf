provider "aws" {
  region = "us-east-1"
}

# Create a Security Group
resource "aws_security_group" "web_sg" {
  name        = "web-app-sg"
  description = "Allow inbound traffic on SSH and app port"
  
  # Allow SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Replace with your IP for better security
  }

  # Allow access to app (port 8080)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an IAM Role for EC2 to access ECR
resource "aws_iam_role" "ec2_role" {
  name = "EC2ECRAccessRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Attach ECR Full Access Policy to the IAM Role
resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

# Create an Instance Profile to attach the role to EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "EC2InstanceProfile"
  role = aws_iam_role.ec2_role.name
}

# Create an EC2 Instance
resource "aws_instance" "web_app" {
  ami           = "ami-053b0d53c279acc90"  # Ubuntu 22.04 in us-east-1
  instance_type = "t2.micro"
  key_name      = "your-key-pair"  # Replace with your SSH key pair
  security_groups = [aws_security_group.web_sg.name]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y docker.io
              sudo systemctl start docker
              sudo usermod -aG docker ubuntu
              newgrp docker
              $(aws ecr get-login --no-include-email --region us-east-1)
              EOF

  tags = {
    Name = "WebAppServer"
  }
}
