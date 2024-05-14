variable "region" {
  description = "AWS Region to create infrastructure in"
  type        = string
}


variable "instances_per_subnet" {
  description = "Count of EC2 Instances to create in each Subnet"
  type        = number
}


variable "ssh_public_key_file" {
  description = "Path to SSH Public key to deploy onto instances"
  type        = string
  default     = null
}


variable "ssh_public_key" {
  description = "SSH Public key contents to allow incoming SSH connections"
  type        = string
  default     = null
}

variable "deploy_bastion" {
  description = "Set to true if you want to deploy bastion"
  type        = bool
  default     = false
}
