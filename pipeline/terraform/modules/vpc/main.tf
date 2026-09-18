# NovaPay VPC Module — Multi-AZ VPC with Public/Private Subnets
# Compliance: PCI-DSS Req 1.2 (network segmentation)
# Ref: Deliverable 5 (Environment Promotion) — environment isolation

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
# VPC
# ---------------------------------------------------------------
resource "aws_vpc" "novapay" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.common_tags, {
    Name = "${var.environment}-novapay-vpc"
  })
}

# ---------------------------------------------------------------
# Subnets — Public (ALB/NAT) + Private (EKS/RDS)
# ---------------------------------------------------------------
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.novapay.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name                                          = "${var.environment}-novapay-public-${var.availability_zones[count.index]}"
    "kubernetes.io/role/elb"                       = "1"
    "kubernetes.io/cluster/${var.cluster_name}"     = "shared"
  })
}

resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.novapay.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + length(var.availability_zones))
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.common_tags, {
    Name                                          = "${var.environment}-novapay-private-${var.availability_zones[count.index]}"
    "kubernetes.io/role/internal-elb"              = "1"
    "kubernetes.io/cluster/${var.cluster_name}"     = "shared"
  })
}

resource "aws_subnet" "database" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.novapay.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 2 * length(var.availability_zones))
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.common_tags, {
    Name = "${var.environment}-novapay-database-${var.availability_zones[count.index]}"
  })
}

# ---------------------------------------------------------------
# Internet Gateway + NAT Gateway
# ---------------------------------------------------------------
resource "aws_internet_gateway" "novapay" {
  vpc_id = aws_vpc.novapay.id

  tags = merge(var.common_tags, {
    Name = "${var.environment}-novapay-igw"
  })
}

resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"

  tags = merge(var.common_tags, {
    Name = "${var.environment}-novapay-nat-eip-${count.index}"
  })
}

resource "aws_nat_gateway" "novapay" {
  count = length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.common_tags, {
    Name = "${var.environment}-novapay-nat-${count.index}"
  })

  depends_on = [aws_internet_gateway.novapay]
}

# ---------------------------------------------------------------
# Route Tables
# ---------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.novapay.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.novapay.id
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-novapay-public-rt"
  })
}

resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.novapay.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.novapay[count.index].id
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-novapay-private-rt-${count.index}"
  })
}

resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ---------------------------------------------------------------
# VPC Flow Logs — RBI Section 6.1 (comprehensive audit trails)
# ---------------------------------------------------------------
resource "aws_flow_log" "novapay" {
  vpc_id               = aws_vpc.novapay.id
  traffic_type         = "ALL"
  log_destination      = var.flow_log_bucket_arn
  log_destination_type = "s3"

  tags = merge(var.common_tags, {
    Name = "${var.environment}-novapay-flow-logs"
  })
}
