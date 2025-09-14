terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "~> 0.90"
    }
  }
}

# Configure AWS Provider
provider "aws" {
  region = var.aws_region
}

# Configure Snowflake Provider
provider "snowflake" {
  account    = var.snowflake_account
  username   = var.snowflake_username
  password   = var.snowflake_password
  region     = var.snowflake_region
  warehouse  = var.snowflake_warehouse
  role       = "USERADMIN"
}

# S3 Bucket for Mantra App
resource "aws_s3_bucket" "mantra_app_bucket" {
  bucket = "${var.project_name}-${var.environment}-bucket"

  tags = {
    Name        = "${var.project_name}-${var.environment}-bucket"
    Environment = var.environment
    Project     = var.project_name
  }
}

# S3 Bucket versioning
resource "aws_s3_bucket_versioning" "mantra_app_bucket_versioning" {
  bucket = aws_s3_bucket.mantra_app_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "mantra_app_bucket_encryption" {
  bucket = aws_s3_bucket.mantra_app_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket public access block
resource "aws_s3_bucket_public_access_block" "mantra_app_bucket_pab" {
  bucket = aws_s3_bucket.mantra_app_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM Policy for S3 Full Access
resource "aws_iam_policy" "s3_full_access" {
  name        = "${var.project_name}-s3-full-access-policy"
  description = "Full access to S3 for Mantra App"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = [
          aws_s3_bucket.mantra_app_bucket.arn,
          "${aws_s3_bucket.mantra_app_bucket.arn}/*"
        ]
      }
    ]
  })
}

# IAM User for application
resource "aws_iam_user" "mantra_app_user" {
  name = "${var.project_name}-${var.environment}-user"

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Attach S3 policy to user
resource "aws_iam_user_policy_attachment" "mantra_app_s3_attach" {
  user       = aws_iam_user.mantra_app_user.name
  policy_arn = aws_iam_policy.s3_full_access.arn
}

# Generate access keys for the IAM user
resource "aws_iam_access_key" "mantra_app_access_key" {
  user = aws_iam_user.mantra_app_user.name
}

# Store AWS credentials in AWS Secrets Manager
resource "aws_secretsmanager_secret" "aws_credentials" {
  name                    = "${var.project_name}-${var.environment}-aws-credentials"
  description             = "AWS credentials for Mantra App"
  recovery_window_in_days = 7

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_secretsmanager_secret_version" "aws_credentials_version" {
  secret_id = aws_secretsmanager_secret.aws_credentials.id
  secret_string = jsonencode({
    AWS_ACCESS_KEY_ID     = aws_iam_access_key.mantra_app_access_key.id
    AWS_SECRET_ACCESS_KEY = aws_iam_access_key.mantra_app_access_key.secret
    AWS_REGION           = var.aws_region
    S3_BUCKET_NAME       = aws_s3_bucket.mantra_app_bucket.id
  })
}

# Store Snowflake credentials in AWS Secrets Manager
resource "aws_secretsmanager_secret" "snowflake_credentials" {
  name                    = "${var.project_name}-${var.environment}-snowflake-credentials"
  description             = "Snowflake credentials for Mantra App"
  recovery_window_in_days = 7

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_secretsmanager_secret_version" "snowflake_credentials_version" {
  secret_id = aws_secretsmanager_secret.snowflake_credentials.id
  secret_string = jsonencode({
    SNOWFLAKE_ACCOUNT   = var.snowflake_account
    SNOWFLAKE_USERNAME  = var.snowflake_username
    SNOWFLAKE_PASSWORD  = var.snowflake_password
    SNOWFLAKE_REGION    = var.snowflake_region
    SNOWFLAKE_WAREHOUSE = var.snowflake_warehouse
    SNOWFLAKE_DATABASE  = var.snowflake_database
    SNOWFLAKE_SCHEMA    = var.snowflake_schema
  })
}

# IAM Role for Snowflake to access S3 (for Iceberg)
resource "aws_iam_role" "snowflake_s3_role" {
  name = "${var.project_name}-snowflake-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.snowflake_account_id}:root"
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.snowflake_external_id
          }
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM Policy for Snowflake S3 access
resource "aws_iam_policy" "snowflake_s3_policy" {
  name        = "${var.project_name}-snowflake-s3-policy"
  description = "Policy for Snowflake to access S3 bucket for Iceberg"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.mantra_app_bucket.arn,
          "${aws_s3_bucket.mantra_app_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Attach policy to Snowflake role
resource "aws_iam_role_policy_attachment" "snowflake_s3_attach" {
  role       = aws_iam_role.snowflake_s3_role.name
  policy_arn = aws_iam_policy.snowflake_s3_policy.arn
}