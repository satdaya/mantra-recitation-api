#!/bin/bash
# Script to get values from Terraform for SQL scripts
# Run this to get the values you need to replace in the SQL scripts

echo "=== Terraform Output Values ==="
echo ""

echo "S3 Bucket Name:"
terraform output -raw s3_bucket_name

echo ""
echo "AWS Account ID: (from IAM role ARN)"
terraform output -raw snowflake_s3_role_arn | cut -d':' -f5

echo ""  
echo "IAM Role Name:"
terraform output -raw snowflake_s3_role_arn | cut -d'/' -f2

echo ""
echo "Full IAM Role ARN:"
terraform output -raw snowflake_s3_role_arn

echo ""
echo "=== Use these values to replace placeholders in SQL scripts ==="