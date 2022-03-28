variable "countvm" {
  type    = number
  default = 3
}
variable "accesskey" {}
variable "secretkey" {}
variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "cluster_name" {
  type    = string
  default = "mn_cluster"
}