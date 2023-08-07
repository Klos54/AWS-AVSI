# Configuration Terraform de base
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "eu-west-3"
}

# Création de la VPC, du sous-réseau, de la passerelle internet et de la route
resource "aws_vpc" "JESTIVAL-VPC" {
  cidr_block = "10.0.0.0/24"
  tags = {
    Name = "JESTIVAL-VPC"
  }
}

resource "aws_subnet" "JESTIVAL-SUBNET1" {
  vpc_id     = aws_vpc.JESTIVAL-VPC.id
  cidr_block = "10.0.0.0/24"
  tags = {
    Name = "JESTIVAL-SUBNET1"
  }
}

resource "aws_internet_gateway" "JESTIVAL-IGW" {
}

resource "aws_internet_gateway_attachment" "JESTIVAL-IGW-ATTACHMENT" {
  vpc_id             = aws_vpc.JESTIVAL-VPC.id
  internet_gateway_id = aws_internet_gateway.JESTIVAL-IGW.id
}

resource "aws_route" "JESTIVAL-ROUTE-DEFAULT" {
  route_table_id         = aws_vpc.JESTIVAL-VPC.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.JESTIVAL-IGW.id
  depends_on = [
    aws_internet_gateway_attachment.JESTIVAL-IGW-ATTACHMENT
  ]
}

# Création du groupe de sécurité ouvert pour HTTP
resource "aws_security_group" "JESTIVAL-SG" {
  name        = "JESTIVAL-SG"
  description = "JESTIVAL-SG"
  vpc_id      = aws_vpc.JESTIVAL-VPC.id

  ingress {
    description = "JESTIVAL-SG-ALLOW-WEB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Autoriser l'accès SSH uniquement depuis l'adresse IP spécifique
  # Remplacez "xxx.xxx.xxx.xxx" par l'adresse IP autorisée
  ingress {
    description = "JESTIVAL-SG-ALLOW-SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["xxx.xxx.xxx.xxx/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "JESTIVAL-SG"
  }
}

# Création de l'instance EC2 avec Docker, Jenkins, Ansible et Nessus
resource "aws_instance" "JESTIVAL-INSTANCE" {
  ami                          = "ami-0f61de2873e29e866"
  subnet_id                    = aws_subnet.JESTIVAL-SUBNET1.id
  instance_type                = "t2.micro"
  associate_public_ip_address  = true
  key_name                     = "test_keypair"
  security_groups              = [aws_security_group.JESTIVAL-SG.id]
  tags = {
    Name = "JESTIVAL-INSTANCE"
  }

  user_data = <<-EOT
              #!/bin/bash
			  # Mise à jour du système
              sudo apt update
              sudo apt upgrade -y
			  
              # Installation de Docker
              sudo apt install -y docker
			  
			  # Installation d'Ansible
			  sudo apt install ansible sshpass
			  
			  
              # Permet de lancer des conteneurs Docker en mode "unprivileged"
              sudo usermod -v 1000000-1000999999 -w 1000000-1000999999 root

              # Installation de Java et de curl (nécessaire à Jenkins)
              sudo apt update
              sudo apt install openjdk-17-jre curl systemctl -y

              # Installation de Jenkins
              curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
                /usr/share/keyrings/jenkins-keyring.asc > /dev/null
              echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
                https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
                /etc/apt/sources.list.d/jenkins.list > /dev/null
              sudo apt update
              sudo apt install jenkins -y

              # Lancement de Jenkins en plus du démarrage du système
              sudo systemctl enable --now jenkins

              # Installation de Nessus sur un conteneur Docker
              docker pull tenable/nessus:latest-ubuntu
              docker run -d --name Nessus -p 8834:8834 tenable/nessus:latest-ubuntu

              # [Insérez ici les commandes d'installation de Nessus]
              EOT
}

# Provisioning de l'instance EC2 pour exécuter le script utilisateur
resource "aws_instance" "JESTIVAL-INSTANCE" {
  provisioner "local-exec" {
    command = "echo ${self.public_ip} > public_ip"
  }
}
