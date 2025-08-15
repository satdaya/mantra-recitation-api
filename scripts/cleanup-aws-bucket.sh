#!/bin/bash

# 🗑️ AWS S3 Bucket Cleanup Script
# Safely removes S3 bucket and associated resources

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 <bucket-name> [iam-role-name] [iam-policy-name]"
    echo ""
    echo "Examples:"
    echo "  $0 mantra-recitation-private-123456789"
    echo "  $0 mantra-recitation-private-123456789 SnowflakeIcebergRole SnowflakeIcebergPolicy"
    echo ""
    echo "This script will:"
    echo "  1. Empty the S3 bucket (delete all objects and versions)"
    echo "  2. Delete the S3 bucket"
    echo "  3. Optionally delete associated IAM role and policy"
    echo "  4. Delete logging bucket if it exists"
    exit 1
fi

BUCKET_NAME="$1"
IAM_ROLE_NAME="${2:-SnowflakeIcebergRole}"
IAM_POLICY_NAME="${3:-SnowflakeIcebergPolicy}"
LOGGING_BUCKET="${BUCKET_NAME}-logs"

echo -e "${RED}🗑️  AWS S3 BUCKET CLEANUP${NC}"
echo "=========================="
echo ""
echo "This will DELETE the following resources:"
echo "  - S3 Bucket: $BUCKET_NAME"
echo "  - Logging Bucket: $LOGGING_BUCKET (if exists)"
echo "  - IAM Role: $IAM_ROLE_NAME (if specified)"
echo "  - IAM Policy: $IAM_POLICY_NAME (if specified)"
echo ""
print_warning "THIS ACTION CANNOT BE UNDONE!"
echo ""

# Confirmation prompt
read -p "Are you sure you want to proceed? Type 'DELETE' to confirm: " confirmation

if [ "$confirmation" != "DELETE" ]; then
    echo "Operation cancelled."
    exit 0
fi

echo ""
print_info "Starting cleanup process..."

# Check AWS CLI configuration
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    print_error "AWS CLI not configured. Please run 'aws configure' first."
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_success "Connected to AWS Account: $AWS_ACCOUNT_ID"

# Step 1: Empty the main bucket
echo ""
print_info "Step 1: Emptying main bucket..."

if aws s3 ls "s3://$BUCKET_NAME" >/dev/null 2>&1; then
    # Remove all objects (including versions)
    echo "Removing all objects and versions..."
    aws s3api delete-objects \
        --bucket "$BUCKET_NAME" \
        --delete "$(aws s3api list-object-versions \
            --bucket "$BUCKET_NAME" \
            --output json \
            --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" \
        2>/dev/null || true
    
    # Remove delete markers
    aws s3api delete-objects \
        --bucket "$BUCKET_NAME" \
        --delete "$(aws s3api list-object-versions \
            --bucket "$BUCKET_NAME" \
            --output json \
            --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')" \
        2>/dev/null || true
    
    # Final cleanup with s3 rm
    aws s3 rm "s3://$BUCKET_NAME" --recursive 2>/dev/null || true
    
    print_success "Main bucket emptied"
else
    print_warning "Main bucket doesn't exist or is not accessible"
fi

# Step 2: Delete the main bucket
echo ""
print_info "Step 2: Deleting main bucket..."

if aws s3 ls "s3://$BUCKET_NAME" >/dev/null 2>&1; then
    aws s3 rb "s3://$BUCKET_NAME"
    print_success "Main bucket deleted: $BUCKET_NAME"
else
    print_warning "Main bucket already deleted or doesn't exist"
fi

# Step 3: Clean up logging bucket
echo ""
print_info "Step 3: Cleaning up logging bucket..."

if aws s3 ls "s3://$LOGGING_BUCKET" >/dev/null 2>&1; then
    # Empty logging bucket
    aws s3 rm "s3://$LOGGING_BUCKET" --recursive 2>/dev/null || true
    
    # Remove versions from logging bucket
    aws s3api delete-objects \
        --bucket "$LOGGING_BUCKET" \
        --delete "$(aws s3api list-object-versions \
            --bucket "$LOGGING_BUCKET" \
            --output json \
            --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" \
        2>/dev/null || true
    
    # Delete logging bucket
    aws s3 rb "s3://$LOGGING_BUCKET"
    print_success "Logging bucket deleted: $LOGGING_BUCKET"
else
    print_warning "Logging bucket doesn't exist"
fi

# Step 4: Clean up IAM resources (if specified)
if [ "$#" -gt 1 ]; then
    echo ""
    print_info "Step 4: Cleaning up IAM resources..."
    
    # Detach policy from role
    if aws iam get-role --role-name "$IAM_ROLE_NAME" >/dev/null 2>&1; then
        print_info "Detaching policy from role..."
        aws iam detach-role-policy \
            --role-name "$IAM_ROLE_NAME" \
            --policy-arn "arn:aws:iam::$AWS_ACCOUNT_ID:policy/$IAM_POLICY_NAME" \
            2>/dev/null || print_warning "Policy was not attached to role"
        
        # Delete IAM role
        print_info "Deleting IAM role..."
        aws iam delete-role --role-name "$IAM_ROLE_NAME"
        print_success "IAM role deleted: $IAM_ROLE_NAME"
    else
        print_warning "IAM role doesn't exist: $IAM_ROLE_NAME"
    fi
    
    # Delete IAM policy
    if aws iam get-policy --policy-arn "arn:aws:iam::$AWS_ACCOUNT_ID:policy/$IAM_POLICY_NAME" >/dev/null 2>&1; then
        print_info "Deleting IAM policy..."
        
        # Delete all policy versions except default
        VERSIONS=$(aws iam list-policy-versions --policy-arn "arn:aws:iam::$AWS_ACCOUNT_ID:policy/$IAM_POLICY_NAME" --query 'Versions[?!IsDefaultVersion].VersionId' --output text)
        for version in $VERSIONS; do
            aws iam delete-policy-version \
                --policy-arn "arn:aws:iam::$AWS_ACCOUNT_ID:policy/$IAM_POLICY_NAME" \
                --version-id "$version" 2>/dev/null || true
        done
        
        # Delete the policy
        aws iam delete-policy --policy-arn "arn:aws:iam::$AWS_ACCOUNT_ID:policy/$IAM_POLICY_NAME"
        print_success "IAM policy deleted: $IAM_POLICY_NAME"
    else
        print_warning "IAM policy doesn't exist: $IAM_POLICY_NAME"
    fi
fi

# Step 5: Clean up local files
echo ""
print_info "Step 5: Cleaning up local configuration files..."

CONFIG_FILE="aws-bucket-config.txt"
if [ -f "$CONFIG_FILE" ]; then
    rm "$CONFIG_FILE"
    print_success "Removed local config file: $CONFIG_FILE"
fi

# Final summary
echo ""
echo -e "${GREEN}🎉 CLEANUP COMPLETED! 🎉${NC}"
echo "========================"
echo ""
echo "The following resources have been removed:"
echo "  ✅ S3 Bucket: $BUCKET_NAME"
echo "  ✅ Logging Bucket: $LOGGING_BUCKET"
if [ "$#" -gt 1 ]; then
    echo "  ✅ IAM Role: $IAM_ROLE_NAME"
    echo "  ✅ IAM Policy: $IAM_POLICY_NAME"
fi
echo "  ✅ Local configuration files"
echo ""
print_warning "Remember to update your Snowflake configuration if you were using these resources!"
echo ""
print_success "Cleanup completed successfully! 🧹"