variable "control_cidr" {
  description = "CIDR for maintenance: inbound traffic will be allowed from this IPs"
  default     = "174.102.0.0/18"
}

## ssh-keygen -y -f GEHC-037
variable "default_keypair_public_key" {
  description = "Public Key of the default keypair"
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCUwCqL3CF7aEJbEJGZFtHImz+QdeNVD8ZR8ogj+HQZN50vQXVx/ciGtDAGaFrpjhrpwrUx26etXC3Hz61x2V/kuwp8VdjKQkcGgFXPao0VanzLe6+YHiCtQ6NWK2Or4BzgsuTHysdWj/afEbxFkzlkOImC4HljujiJ2ng70+Moa8ehaxeMuHJoZdck1EwoqTCOegG/rMxe6Xf5S3IlkIpUFdgtRb2We3qXGeNz0PkYAnU2C8doavgPNCvo46qPXQeq/SN1TcoJaiPHxrCbsdb5cntbXPkvax2U+QcnjkYwigpEOO4qBQg06Klj0+iJageBP7Zr0ftZyfTMV3kQQ6y5"
}

variable "default_keypair_name" {
  description = "Name of the KeyPair used for all nodes"
  default     = "GEHC-037"
}

variable "vpc_name" {
  description = "Name of the VPC"
  default     = "kubernetes"
}

variable "elb_name" {
  description = "Name of the ELB for Kubernetes API"
  default     = "kubernetes"
}

variable "owner" {
  default = "Kubernetes"
}

variable "ansibleFilter" {
  description = "`ansibleFilter` tag value added to all instances, to enable instance filtering in Ansible dynamic inventory"

  # IF YOU CHANGE THIS YOU HAVE TO CHANGE instance_filters = tag:ansibleFilter=Kubernetes01 in ./ansible/hosts/ec2.ini
  default = "Kubernetes01"
}

# Networking setup
variable "region" {
  default = "us-east-1"
}

# TODO: lookup_map
variable "zone" {
  default = "us-east-1a"
}

### VARIABLES BELOW MUST NOT BE CHANGED ###

variable vpc_cidr {
  default = "10.43.0.0/16"
}

variable kubernetes_pod_cidr {
  default = "10.200.0.0/16"
}

# Instances Setup
# TODO: filter_map this guy
variable "amis" {
  description = "Default AMIs to use for nodes depending on the region"
  type        = "map"

  default = {
    ap-northeast-1 = "ami-0567c164"
    ap-southeast-1 = "ami-a1288ec2"
    cn-north-1     = "ami-d9f226b4"
    eu-central-1   = "ami-8504fdea"
    eu-west-1      = "ami-0d77397e"
    sa-east-1      = "ami-e93da085"
    us-east-1      = "ami-40d28157"
    us-west-1      = "ami-6e165d0e"
    us-west-2      = "ami-a9d276c9"
  }
}

variable "default_instance_user" {
  default = "ubuntu"
}

variable "etcd_instance_type" {
  default = "t2.small"
}

variable "controller_instance_type" {
  default = "t2.small"
}

variable "worker_instance_type" {
  default = "t2.small"
}

variable "kubernetes_cluster_dns" {
  default = "10.31.0.1"
}
