output "time_last_deployed" {
  value = timestamp()
}

output "url" {
  value = "http://${aws_lb.app.dns_name}"
}

output "bastion_ip" {
  value = var.deploy_bastion ? aws_eip.bastion[0].public_ip : null
}
