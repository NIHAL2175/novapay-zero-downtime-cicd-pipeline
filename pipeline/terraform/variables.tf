variable "aws_region" {
  description = "AWS region for NovaPay infrastructure"
  type        = string
  default     = "ap-south-1"  # Mumbai — primary region for Indian banking
}

variable "environment" {
  description = "Environment name (dev, staging, pre-prod, production)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for multi-AZ deployment"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "node_instance_types" {
  description = "EC2 instance types for EKS worker nodes"
  type        = list(string)
  default     = ["m6i.xlarge"]
}

variable "node_desired_size" {
  type    = number
  default = 3
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 10
}

variable "enable_public_access" {
  description = "Enable public access to EKS API server"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption (secrets, storage)"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the EKS API server"
  type        = list(string)
  default     = []
}

variable "flow_log_bucket_arn" {
  description = "S3 bucket ARN for VPC flow logs"
  type        = string
}

variable "rds_instance_class" {
  type    = string
  default = "db.r6g.xlarge"
}

variable "rds_allocated_storage" {
  type    = number
  default = 100
}

variable "rds_max_allocated_storage" {
  type    = number
  default = 500
}

variable "rds_multi_az" {
  type    = bool
  default = true
}

variable "rds_deletion_protection" {
  type    = bool
  default = true
}

variable "rds_backup_retention_days" {
  type    = number
  default = 35
}

variable "db_password" {
  description = "Database master password (managed via HashiCorp Vault)"
  type        = string
  sensitive   = true
}
