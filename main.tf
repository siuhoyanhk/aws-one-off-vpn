terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# --- VARIABLES ---

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS Region to deploy the VPN in."
}

variable "auto_shutdown_hours" {
  type        = number
  default     = 24
  description = "How many hours should the VPN run before auto-shutting down?"
}

variable "instance_type" {
  type        = string
  default     = "t3.medium"
  description = "The EC2 instance type to use for the VPN server."
}

provider "aws" {
  region = var.aws_region
}

# 1. Reliable Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# 2. Generate Password
resource "random_password" "vpn_password" {
  length           = 16
  special          = false
  override_special = "_%@"
}

# 3. Security Group
resource "aws_security_group" "vpn_sg" {
  name        = "openvpn-sg-${var.aws_region}-${random_password.vpn_password.result}"
  description = "Allow OpenVPN"

  # Used by the OpenVPN app to authenticate and pull the profile
  ingress {
    from_port   = 943
    to_port     = 943
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Required for the actual VPN tunnel traffic to transmit
  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 4. EC2 Instance (No SSH Keys needed)
resource "aws_instance" "vpn_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.vpn_sg.id]

  instance_initiated_shutdown_behavior = "terminate"

  # Install script + IP Fix + DCO Fix + Dynamic Auto-Stop
  user_data = <<-EOF
              #!/bin/bash
              # 1. Install
              apt-get update
              apt-get install -y ca-certificates wget net-tools gnupg curl
              wget -qO - https://as-repository.openvpn.net/as-repo-public.gpg | apt-key add -
              echo "deb http://as-repository.openvpn.net/as/debian jammy main" > /etc/apt/sources.list.d/openvpn-as-repo.list
              apt-get update
              apt-get install -y openvpn-as

              # Wait for sacli
              while [ ! -f /usr/local/openvpn_as/scripts/sacli ]; do sleep 2; done

              # 2. Get Public IP
              TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
              PUBLIC_IP=`curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4`

              # 3. Configure
              cd /usr/local/openvpn_as/scripts
              ./sacli --user "openvpn" --new_pass "${random_password.vpn_password.result}" SetLocalPassword
              ./sacli --key "host.name" --value "$PUBLIC_IP" ConfigPut
              # DCO FIX
              ./sacli --key "vpn.server.compression_enabled" --value "no" ConfigPut
              ./sacli --key "vpn.client.compression" --value "no" ConfigPut
              
              ./sacli start

              # 4. Auto-Shutdown (Dynamic based on user variable)
              shutdown -h +${var.auto_shutdown_hours * 60} "Auto-stop in ${var.auto_shutdown_hours} hours"
              EOF

  user_data_replace_on_change = true
  
  tags = {
    Name = "One-Off-VPN-${var.aws_region}"
  }
}

# --- OUTPUTS ---

output "z_instructions" {
  value = <<EOT

  --------------------------------------------------------------
  VPN INSTANCE LAUNCHED! (${var.aws_region})
  --------------------------------------------------------------
  ⏳ Please wait 3 minutes for OpenVPN to finish installing in the background.

  1. Reveal your password (copy-paste this command):
     terraform output -raw vpn_password

  2. Connect using the OpenVPN Connect App:
     - Open the OpenVPN app on your phone or computer
     - Select "URL" to import a new profile
     - Enter URL: ${aws_instance.vpn_server.public_ip}
     - Username: openvpn
     - Password: <paste the password from step 1>

     (If the app warns you about an untrusted certificate, 
      tap "Accept" to proceed)

  3. Auto-Stop:
     This ${var.instance_type} instance will automatically shutdown and terminate in ${var.auto_shutdown_hours} hours.
  --------------------------------------------------------------
  EOT
}

output "vpn_password" {
  description = "VPN Password"
  value       = random_password.vpn_password.result
  sensitive   = true
}
