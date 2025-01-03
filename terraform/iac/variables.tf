# variables for resource VPC 
variable "cidr_block" {
  description = "cidr block for vpc"
  default     = "10.20.0.0/16"
}
# variables for subnets
variable "cidr_block_pubsn1" {
  description = "cidr block for public subnet #1"
  default     = "10.20.0.0/24"
}
variable "cidr_block_pubsn2" {
  description = "cidr block for public subnet #2"
  default     = "10.20.64.0/24"
}
variable "cidr_block_privsn1" {
  description = "cidr block for private subnet #1"
  default     = "10.20.128.0/24"
}
variable "cidr_block_privsn2" {
  description = "cidr block for private subnet #2"
  default     = "10.20.192.0/24"
}
# vars for route tables 
variable "cidr_block_public_rt" {
  description = "cidr for public route table"
  default     = "0.0.0.0/0"
}
variable "cidr_block_private_rt" {
  description = "cidr for private route table"
  default     = "0.0.0.0/0"
}