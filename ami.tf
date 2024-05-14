locals {
  instance_count = var.instances_per_subnet * length(module.vpc.private_subnets)

  settings = {
    debian = {
      owners      = ["136693071363"]
      name_regex  = "^debian-12-amd64"
      install_ssm = true
    }
    ubuntu = {
      owners      = ["099720109477"]
      name_regex  = "^ubuntu/images/hvm-ssd/ubuntu-jammy-22.04"
      install_ssm = false
    }
    amazonlinux2 = {
      owners      = ["137112412989"]
      name_regex  = "^amzn2-ami-kernel-[0-9.]*-hvm-[0-9.]*-x86_64-gp2"
      install_ssm = false
    }
  }

  templates        = fileset(path.module, "templates/*.tftpl")
  default_template = "templates/default.tftpl"
  cloud_init_templates = { for k, v in local.settings :
    k => contains(local.templates, "templates/${k}.tftpl") ? "templates/${k}.tftpl" : local.default_template
  }
  complete_settings = { for k, v in local.settings : k => merge(v, { cloud_init = local.cloud_init_templates[k] }) }

  amis                   = keys(local.settings)
  instance_distributions = [for i in range(local.instance_count) : local.amis[i % length(local.amis)]]
  instance_settings      = [for i in range(local.instance_count) : local.complete_settings[local.instance_distributions[i]]]
}


data "aws_ami" "this" {
  for_each    = local.settings
  most_recent = true
  name_regex  = local.settings[each.key].name_regex
  owners      = local.settings[each.key].owners

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
