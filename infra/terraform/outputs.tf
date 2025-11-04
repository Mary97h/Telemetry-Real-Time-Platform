# infra/terraform/outputs.tf
output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "s3_bucket_name" {
  description = "S3 bucket for Flink state"
  value       = aws_s3_bucket.flink_state.bucket
}

output "flink_iam_role_arn" {
  description = "IAM Role ARN for Flink"
  value       = aws_iam_role.flink_role.arn
}