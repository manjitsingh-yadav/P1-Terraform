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

resource "aws_default_vpc" "default" {

}

# Create a security group
# 1. Jenkins Server -> 80 TCP, 22 TCP, CIDR ["0.0.0.0/0"]
resource "aws_security_group" "Jenkins_server_sg" {
  name   = "Jenkins_server_sg"
  vpc_id = aws_default_vpc.default.id

  dynamic "ingress" {
    iterator = port
    for_each = var.ingress_rules
    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
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
  ami                    = data.aws_ami.ubuntu.id
  key_name               = var.aws_key_name
  instance_type          = var.ec2_instance_type
  vpc_security_group_ids = [aws_security_group.Jenkins_server_sg.id]
  subnet_id              = tolist(data.aws_subnet_ids.default_subnets.ids)[2]

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