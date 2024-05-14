data "http" "my_ip" {
  url = "https://ifconfig.me"
}

resource "aws_security_group" "bastion_access" {
  name   = "bastion-access"
  vpc_id = module.vpc.vpc_id
}


# Need this to connect to bastion host
resource "aws_vpc_security_group_ingress_rule" "bastion_ssh_access" {
  security_group_id = aws_security_group.bastion_access.id

  from_port   = 22
  ip_protocol = "tcp"
  to_port     = 22
  cidr_ipv4   = "${data.http.my_ip.response_body}/32"

}


# Need this to connect to other instances
resource "aws_vpc_security_group_egress_rule" "bastion_ssh_access" {
  security_group_id = aws_security_group.bastion_access.id

  from_port   = 22
  ip_protocol = "tcp"
  to_port     = 22
  cidr_ipv4   = module.vpc.vpc_cidr_block

}


# Need this to connect to other instances
resource "aws_vpc_security_group_ingress_rule" "bastion_to_ec2_ssh_access" {
  security_group_id = aws_security_group.ec2_lb_access.id

  from_port   = 22
  ip_protocol = "tcp"
  to_port     = 22

  referenced_security_group_id = aws_security_group.bastion_access.id
}


# Need this to install SSM Agent on the host
resource "aws_vpc_security_group_egress_rule" "bastion_web_access" {
  for_each          = toset(["80", "443"])
  security_group_id = aws_security_group.bastion_access.id

  from_port   = each.key
  ip_protocol = "tcp"
  to_port     = each.key
  cidr_ipv4   = "0.0.0.0/0"
}


resource "aws_instance" "bastion" {
  count                = var.deploy_bastion ? 1 : 0
  ami                  = data.aws_ami.debian.id
  instance_type        = "t3.micro"
  subnet_id            = module.vpc.public_subnets[0]
  key_name             = local.public_key_id
  iam_instance_profile = aws_iam_instance_profile.this.name

  vpc_security_group_ids = [
    aws_security_group.bastion_access.id
  ]
  associate_public_ip_address = true
  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/sh
    set -e
    set -x
    wget -q --show-progress -O /tmp/ssm.deb https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
    dpkg -i /tmp/ssm.deb
    sleep 5
    systemctl status amazon-ssm-agent
  EOF

  tags = {
    Name         = "bastion"
    role         = "bastion"
    distribution = "debian"
  }
}


resource "aws_eip" "bastion" {
  count      = var.deploy_bastion ? 1 : 0
  domain     = "vpc"
  depends_on = [module.vpc.igw_id]

  tags = {
    "Name" = "bastion"
  }
}


resource "aws_eip_association" "eip_assoc" {
  count         = var.deploy_bastion ? 1 : 0
  instance_id   = aws_instance.bastion[0].id
  allocation_id = aws_eip.bastion[0].id
}
