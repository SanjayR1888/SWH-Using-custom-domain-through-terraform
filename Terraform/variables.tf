// Variable values from custom.tfvars
variable "environment" {
  description = "The deployment environment (e.g., dev, qa, prod)"
  type        = string
}

variable "domain" {
    description = "Landing page domain"
    type = string
}

variable "route53_zone_id" {
    description = " Hosted Zone ID for the domain"
    type = string
}

variable "region" {
  description = "AWS region for the resources"
  default     = "us-east-1"
}