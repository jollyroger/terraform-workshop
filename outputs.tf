output "time_last_deployed" {
  value = timestamp()
}

output "url" {
  value = "http://${aws_lb.app.dns_name}"
}
