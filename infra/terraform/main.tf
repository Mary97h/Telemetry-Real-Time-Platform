# infra/terraform/main.tf
provider "aws" {
  region = var.aws_region
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.31"

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  eks_managed_node_groups = {
    general = {
      min_size     = 3
      max_size     = 10
      desired_size = 3

      instance_types = ["m5.large"]
      capacity_type  = "ON_DEMAND"
    }
  }

  # Addons
  cluster_addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = {}
    aws-ebs-csi-driver     = {}
  }

  tags = var.tags
}

# S3 Bucket for checkpoints and sinks
resource "aws_s3_bucket" "flink_state" {
  bucket = "${var.cluster_name}-flink-state"
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "flink_state_versioning" {
  bucket = aws_s3_bucket.flink_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# IAM Role for Flink (S3 access)
data "aws_iam_policy_document" "flink_s3" {
  statement {
    actions   = ["s3:*"]
    resources = ["${aws_s3_bucket.flink_state.arn}/*"]
  }
}

resource "aws_iam_role" "flink_role" {
  name = "${var.cluster_name}-flink-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "flink_s3_policy" {
  name   = "flink-s3-policy"
  role   = aws_iam_role.flink_role.id
  policy = data.aws_iam_policy_document.flink_s3.json
}
