# Terraform Infrastructure

This directory contains Terraform configuration to provision AWS and Snowflake resources for the Mantra Recitation API.

## Resources Created

- **S3 Bucket**: Secure bucket with versioning and encryption
- **IAM User**: Application user with S3 full access
- **IAM Policy**: S3 full access policy
- **AWS Secrets Manager**: Stores AWS and Snowflake credentials securely

## Prerequisites

1. Install Terraform (>= 1.0)
2. Configure AWS CLI with appropriate permissions
3. Have Snowflake account credentials ready

## Setup

1. Copy the example variables file:
```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Edit `terraform.tfvars` with your actual values

3. Initialize Terraform:
```bash
terraform init
```

4. Plan the deployment:
```bash
terraform plan
```

5. Apply the configuration:
```bash
terraform apply
```

## Security Notes

- `terraform.tfvars` contains sensitive data and is gitignored
- AWS and Snowflake credentials are stored in AWS Secrets Manager
- S3 bucket has public access blocked by default

## Outputs

After deployment, you can retrieve sensitive values:
```bash
terraform output aws_access_key_id
terraform output -raw aws_secret_access_key
```