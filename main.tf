provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

# Variables for the instance configuration
variable "instance_name" {
  description = "Name of the EC2 instance"
  type        = string
  default     = "DP"
}

variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 1
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
  default     = "ami-0866a3c8686eaeeba"  # Example AMI for Ubuntu, replace if necessary
}

variable "instance_type" {
  description = "Instance type for the EC2 instance"
  type        = string
  default     = "t3a.medium"  # 4 GB RAM, 2 vCPU as requested
}

variable "disk_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 50  # 50 GB storage as per the request
}

variable "assign_public_ip" {
  description = "Assign public IP address to the instance"
  type        = bool
  default     = true
}

variable "ssh_key_name" {
  description = "SSH key name for accessing the instance"
  type        = string
  default     = "dp-key"
}

variable "key_path" {
  description = "Path to the SSH public key file"
  type        = string
  default     = "C:/Users/IT-Support/Downloads/vp_aj.pub"
}

variable "env" {
  description = "Environment tag for the resources"
  type        = string
  default     = "dev"  # Default environment can be changed
}

# Create an SSH Key Pair
resource "aws_key_pair" "my_pub_key" {
  key_name   = var.ssh_key_name
  public_key = file(var.key_path)

  tags = {
    Name        = var.instance_name
    Environment = var.env
  }
}

# Security Group
resource "aws_security_group" "default" {
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH from anywhere, be cautious with this in production
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTP from anywhere
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
  }

  tags = {
    Name = "${var.instance_name}-sg"
  }
}

# Get the default VPC for the region
data "aws_vpc" "default" {
  default = true
}

# EC2 instance
resource "aws_instance" "default" {
  count                    = var.instance_count
  ami                      = var.ami_id
  instance_type            = var.instance_type
  security_groups          = [aws_security_group.default.name]
  associate_public_ip_address = var.assign_public_ip

  root_block_device {
    volume_size = var.disk_size
  }

  # Install Git, Python, and NGINX using user_data script for Ubuntu
  user_data = <<-EOF
              #!/bin/bash
              # Update the package list
              sudo apt-get update -y

              # Install Git, Python, and NGINX
              sudo apt-get install -y git python3 nginx

              # Start and enable NGINX
              sudo systemctl start nginx
              sudo systemctl enable nginx

              # Create the folder for the logs (if not already present)
              sudo mkdir -p /var/www/html/logs
              sudo chmod -R 755 /var/www/html

              # Create a sample status page
              echo '{"status": "running", "result": "pending"}' | sudo tee /var/www/html/status.json

              # Restart NGINX to apply any configuration changes
              sudo systemctl restart nginx
              EOF

  tags = {
    Name = var.instance_name
  }

  key_name = aws_key_pair.my_pub_key.key_name
}

# Output the EC2 instance public IP
output "instance_public_ip" {
  value = aws_instance.default[*].public_ip
}

# Output the EC2 instance IDs
output "instance_ids" {
  value = aws_instance.default[*].id
}
