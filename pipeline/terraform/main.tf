# NovaPay Infrastructure — Root Terraform Composition
# Composes VPC, EKS, and RDS modules for each environment
# Ref: Deliverable 5 (Environment Promotion) — 4-environment model

terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project       = "NovaPay Digital Bank"
      ManagedBy     = "Terraform"
      Environment   = var.environment
      ComplianceTier = "critical"
      Owner         = "sre-team"
    }
  }
}

# ---------------------------------------------------------------
# VPC Module
# ---------------------------------------------------------------
module "vpc" {
  source = "./modules/vpc"

  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  cluster_name        = local.cluster_name
  flow_log_bucket_arn = var.flow_log_bucket_arn

  common_tags = local.common_tags
}

# ---------------------------------------------------------------
# EKS Module
# ---------------------------------------------------------------
module "eks" {
  source = "./modules/eks"

  cluster_name        = local.cluster_name
  kubernetes_version  = var.kubernetes_version
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  enable_public_access = var.enable_public_access
  kms_key_arn         = var.kms_key_arn
  allowed_cidr_blocks = var.allowed_cidr_blocks

  common_tags = local.common_tags
}

# ---------------------------------------------------------------
# RDS Module
# ---------------------------------------------------------------
module "rds" {
  source = "./modules/rds"

  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  database_subnet_ids   = module.vpc.database_subnet_ids
  eks_security_group_id = module.eks.cluster_security_group_id
  instance_class        = var.rds_instance_class
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  multi_az              = var.rds_multi_az
  deletion_protection   = var.rds_deletion_protection
  backup_retention_days = var.rds_backup_retention_days
  db_password           = var.db_password
  kms_key_arn           = var.kms_key_arn

  common_tags = local.common_tags
}

# ---------------------------------------------------------------
# Locals
# ---------------------------------------------------------------
locals {
  cluster_name = "${var.environment}-novapay-eks"

  common_tags = {
    Project     = "NovaPay Digital Bank"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
