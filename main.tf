variable "aws_key_pair" {
  default = "~/aws/aws_keys/default-EC2-3.pem"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

#Configure the AWS provider
provider "aws" {
  region = "us-east-1"
  # version not needed here
}

# Create a security group
# 1. HTTP Server -> 80 TCP, 22 TCP, CIDR ["0.0.0.0/0"]
resource "aws_security_group" "Jenkins_server_sg" {
  name   = "Jenkins_server_sg"
  vpc_id = "vpc-04c148e0e6770e524"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    name = "Jenkins_server_sg"
  }
}

resource "aws_instance" "Jenkins_server" {
  ami                    = "ami-09e67e426f25ce0d7"
  key_name               = "default-EC2-3"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.Jenkins_server_sg.id]
  subnet_id              = "subnet-03f5d07b9c223f3e9"

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file(var.aws_key_pair)
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install ca-certificates",
      "sudo apt install -y openjdk-11-jdk",
      "wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -",
      "sudo sh -c 'echo deb https://pkg.jenkins.io/debian binary/ > /etc/apt/sources.list.d/jenkins.list'",
      "sudo apt update",
      "sudo apt -y install jenkins",
      #"sudo systemctl status jenkins",
      "sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080",
      "sudo sh -c \"iptables-save > /etc/iptables.rules\"",
      "echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections",
      "echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections",
      "sudo apt-get -y install iptables-persistent",
      "sudo ufw allow 8080",
      "java --version",
      "python3 --version"
    ]
  }
}