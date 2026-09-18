# NovaPay RDS Module — PostgreSQL 16 with pgBouncer
# Compliance: RBI Section 5.4 (encryption at rest), PCI-DSS Req 3.4 (data protection)
# Ref: Deliverable 4 (Database Migration) — expand-contract pattern

terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ---------------------------------------------------------------
# DB Subnet Group
# ---------------------------------------------------------------
resource "aws_db_subnet_group" "novapay" {
  name       = "${var.environment}-novapay-db-subnet"
  subnet_ids = var.database_subnet_ids

  tags = merge(var.common_tags, {
    Name = "${var.environment}-novapay-db-subnet-group"
  })
}

# ---------------------------------------------------------------
# RDS Instance — PostgreSQL 16 Multi-AZ
# ---------------------------------------------------------------
resource "aws_db_instance" "novapay" {
  identifier = "${var.environment}-novapay-postgres"

  engine         = "postgres"
  engine_version = "16.2"
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true  # RBI Section 5.4 compliance
  kms_key_id            = var.kms_key_arn

  db_name  = "novapay"
  username = "novapay_admin"
  password = var.db_password  # Managed via Vault — rotated every 90 days

  db_subnet_group_name   = aws_db_subnet_group.novapay.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az                  = var.multi_az  # Required for production
  publicly_accessible       = false
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.environment}-novapay-final-snapshot"

  backup_retention_period = var.backup_retention_days
  backup_window           = "02:00-03:00"  # Off-peak IST (07:30-08:30)
  maintenance_window      = "sun:03:00-sun:04:00"

  # Performance Insights — PCI-DSS monitoring requirement
  performance_insights_enabled          = true
  performance_insights_retention_period = 731  # 2 years for audit
  performance_insights_kms_key_id       = var.kms_key_arn

  # Enhanced Monitoring — RBI observability requirement
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  # Parameter group for banking optimisations
  parameter_group_name = aws_db_parameter_group.novapay.name

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = merge(var.common_tags, {
    Name             = "${var.environment}-novapay-postgres"
    compliance-tier  = "critical"
    data-sensitivity = "pci-dss-cde"
  })
}

# ---------------------------------------------------------------
# Parameter Group — Optimised for banking transactions
# ---------------------------------------------------------------
resource "aws_db_parameter_group" "novapay" {
  family = "postgres16"
  name   = "${var.environment}-novapay-pg16-params"

  parameter {
    name  = "log_statement"
    value = "all"  # RBI audit trail requirement
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"  # Log queries > 1s for performance monitoring
  }

  parameter {
    name  = "ssl"
    value = "1"  # Enforce SSL connections
  }

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements,pgaudit"
  }

  parameter {
    name  = "pgaudit.log"
    value = "ddl,role,write"  # Audit DDL, role changes, and writes
  }

  tags = var.common_tags
}

# ---------------------------------------------------------------
# Security Group — Database access control
# ---------------------------------------------------------------
resource "aws_security_group" "rds" {
  name_prefix = "${var.environment}-novapay-rds-"
  vpc_id      = var.vpc_id
  description = "Security group for NovaPay PostgreSQL RDS"

  ingress {
    description     = "PostgreSQL from EKS worker nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_security_group_id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-novapay-rds-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------
# IAM Role for Enhanced Monitoring
# ---------------------------------------------------------------
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.environment}-novapay-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
