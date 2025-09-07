output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.mantra_app_bucket.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.mantra_app_bucket.arn
}

output "iam_user_name" {
  description = "Name of the IAM user"
  value       = aws_iam_user.mantra_app_user.name
}

output "iam_user_arn" {
  description = "ARN of the IAM user"
  value       = aws_iam_user.mantra_app_user.arn
}

output "aws_access_key_id" {
  description = "AWS Access Key ID"
  value       = aws_iam_access_key.mantra_app_access_key.id
  sensitive   = true
}

output "aws_secret_access_key" {
  description = "AWS Secret Access Key"
  value       = aws_iam_access_key.mantra_app_access_key.secret
  sensitive   = true
}

output "aws_credentials_secret_arn" {
  description = "ARN of AWS credentials secret in Secrets Manager"
  value       = aws_secretsmanager_secret.aws_credentials.arn
}

output "snowflake_credentials_secret_arn" {
  description = "ARN of Snowflake credentials secret in Secrets Manager"
  value       = aws_secretsmanager_secret.snowflake_credentials.arn
}