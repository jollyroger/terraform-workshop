# Terraform AWS Infrastriucture Workshop
# Created on Nov 5, 2022


terraform {
  required_version = ">= 1.5"
  backend "s3" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


provider "aws" {
  region = var.region
}


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "eMASE"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_ipv6        = false
}


resource "aws_security_group" "lb_public_access" {
  name   = "lb-public-access"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
  }
}


resource "aws_security_group" "ec2_lb_access" {
  name   = "ec2-lb-access"
  vpc_id = module.vpc.vpc_id
}


resource "aws_vpc_security_group_ingress_rule" "ec2_lb_access" {
  security_group_id = aws_security_group.ec2_lb_access.id

  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"

  referenced_security_group_id = aws_security_group.lb_public_access.id
}


resource "aws_vpc_security_group_egress_rule" "ec2_internet_access" {
  for_each          = toset(["80", "443"])
  security_group_id = aws_security_group.ec2_lb_access.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = each.value
  ip_protocol = "tcp"
  to_port     = each.value

  tags = {
    Name = "internet access port ${each.value}"
  }
}


resource "aws_instance" "app" {
  count                = var.instances_per_subnet * length(module.vpc.private_subnets)
  ami                  = var.ami_id != "" ? var.ami_id : data.aws_ami.debian.id
  instance_type        = "t3.micro"
  subnet_id            = module.vpc.private_subnets[count.index % length(module.vpc.private_subnets)]
  key_name             = local.public_key_id
  iam_instance_profile = aws_iam_instance_profile.this.name

  vpc_security_group_ids = [
    aws_security_group.ec2_lb_access.id
  ]

  associate_public_ip_address = false

  user_data_replace_on_change = true
  user_data = <<-EOF
    #!/bin/sh
    apt-get update
    apt-get install -y nginx-light
    echo 'Hello from instance app-${count.index}' > /var/www/html/index.html

    wget -q --show-progress -O /tmp/ssm.deb \
      https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
    dpkg -i /tmp/ssm.deb
    sleep 5
    systemctl status amazon-ssm-agent
  EOF

  tags = {
    Name         = "app-${count.index}"
    distribution = "debian"
    role         = "app"
  }

  depends_on = [
    module.vpc.natgw_ids
  ]

  lifecycle {
    ignore_changes = [
      ami
    ]
  }
}


resource "aws_lb" "app" {
  name               = "app"
  internal           = false
  load_balancer_type = "application"
  enable_http2       = true
  ip_address_type    = "ipv4"
  security_groups = [
    aws_security_group.lb_public_access.id
  ]
  subnets = module.vpc.public_subnets
}


resource "aws_lb_target_group" "app" {
  name     = "app"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 10
    timeout             = 5
    interval            = 10
    path                = "/"
    port                = "80"
  }
}


resource "aws_lb_target_group_attachment" "app" {
  count            = length(aws_instance.app)
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app[count.index].id
}


resource "aws_lb_listener" "app-http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
