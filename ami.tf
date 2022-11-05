data "aws_ami" "debian" {
  owners      = ["136693071363"]
  most_recent = true

  filter {
    name   = "name"
    values = ["debian-11-amd64-*"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}
