variable "aws-region" {
  description = "The AWS region to create the infrastructure in"
  default     = "eu-west-3"
}

variable "vpc-cidr-block" {
  description = "The CIDR block for the VPC"
  default     = "172.32.0.0/16"
}

variable "ec2-instance-type" {
  description = "The desired EC2 instance type"
  default     = "t2.micro"
}
