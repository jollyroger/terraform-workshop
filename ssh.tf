# This code defines local.public_key_id variable to be used by EC2 instances.
# User can define var.ssh_public_key as a string or var.ssh_public_key_file as
# a path to the file (the latter takes precenece) to create an SSH key pair in
# AWS. If neither is defined then AWS instances will not have any SSH key
# associated with them

locals {
  public_key    = try(file(var.ssh_public_key_file), var.ssh_public_key)
  public_key_id = local.public_key == null ? null : aws_key_pair.workshop_key[0].key_name
}


resource "aws_key_pair" "workshop_key" {
  count      = local.public_key == null ? 0 : 1
  key_name   = "workshop-key"
  public_key = local.public_key
}
