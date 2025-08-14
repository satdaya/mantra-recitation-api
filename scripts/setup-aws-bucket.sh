#!/bin/bash

# 🔐 Secure AWS S3 Bucket Setup for Mantra Recitation App
# This script creates a private, encrypted S3 bucket with all security best practices

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - CUSTOMIZE THESE VALUES
BUCKET_NAME="mantra-recitation-private-$(date +%s)"  # Unique bucket name
AWS_REGION="us-east-1"  # Change to your preferred region
IAM_ROLE_NAME="SnowflakeIcebergRole"
IAM_POLICY_NAME="SnowflakeIcebergPolicy"
EXTERNAL_ID="mantra-recitation-$(openssl rand -hex 16)"  # Random external ID

echo -e "${BLUE}🔐 Secure S3 Bucket Setup for Mantra Recitation App${NC}"
echo "==============================================="
echo ""

# Function to print status
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if AWS CLI is configured
echo "Checking AWS CLI configuration..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    print_error "AWS CLI not configured. Please run 'aws configure' first."
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_status "Connected to AWS Account: $AWS_ACCOUNT_ID"
echo ""

# Step 1: Create S3 Bucket
echo "Step 1: Creating S3 Bucket..."
if aws s3 ls "s3://$BUCKET_NAME" >/dev/null 2>&1; then
    print_warning "Bucket $BUCKET_NAME already exists. Using existing bucket."
else
    if [ "$AWS_REGION" = "us-east-1" ]; then
        aws s3 mb "s3://$BUCKET_NAME"
    else
        aws s3 mb "s3://$BUCKET_NAME" --region "$AWS_REGION"
    fi
    print_status "Created bucket: $BUCKET_NAME"
fi

# Step 2: Block ALL Public Access (CRITICAL!)
echo ""
echo "Step 2: Blocking ALL public access..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
print_status "Blocked all public access to bucket"

# Step 3: Enable Server-Side Encryption
echo ""
echo "Step 3: Enabling server-side encryption..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            },
            "BucketKeyEnabled": true
        }]
    }'
print_status "Enabled AES-256 server-side encryption"

# Step 4: Enable Versioning
echo ""
echo "Step 4: Enabling versioning for data protection..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled
print_status "Enabled bucket versioning"

# Step 5: Set up Logging (Optional but recommended)
echo ""
echo "Step 5: Setting up access logging..."
LOGGING_BUCKET="${BUCKET_NAME}-logs"
if aws s3 ls "s3://$LOGGING_BUCKET" >/dev/null 2>&1; then
    print_warning "Logging bucket already exists"
else
    if [ "$AWS_REGION" = "us-east-1" ]; then
        aws s3 mb "s3://$LOGGING_BUCKET"
    else
        aws s3 mb "s3://$LOGGING_BUCKET" --region "$AWS_REGION"
    fi
    print_status "Created logging bucket: $LOGGING_BUCKET"
fi

# Enable logging on main bucket
aws s3api put-bucket-logging \
    --bucket "$BUCKET_NAME" \
    --bucket-logging-status '{
        "LoggingEnabled": {
            "TargetBucket": "'$LOGGING_BUCKET'",
            "TargetPrefix": "access-logs/"
        }
    }'
print_status "Enabled access logging"

# Step 6: Create IAM Policy for Snowflake
echo ""
echo "Step 6: Creating IAM policy for Snowflake access..."

IAM_POLICY_JSON='{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowSnowflakeIcebergAccess",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": [
                "arn:aws:s3:::'$BUCKET_NAME'",
                "arn:aws:s3:::'$BUCKET_NAME'/*"
            ]
        },
        {
            "Sid": "AllowListBucketMultipartUploads",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucketMultipartUploads",
                "s3:ListMultipartUploadParts"
            ],
            "Resource": "arn:aws:s3:::'$BUCKET_NAME'"
        }
    ]
}'

# Create IAM policy
if aws iam get-policy --policy-arn "arn:aws:iam::$AWS_ACCOUNT_ID:policy/$IAM_POLICY_NAME" >/dev/null 2>&1; then
    print_warning "IAM policy $IAM_POLICY_NAME already exists"
    # Update the policy
    aws iam create-policy-version \
        --policy-arn "arn:aws:iam::$AWS_ACCOUNT_ID:policy/$IAM_POLICY_NAME" \
        --policy-document "$IAM_POLICY_JSON" \
        --set-as-default
    print_status "Updated existing IAM policy"
else
    aws iam create-policy \
        --policy-name "$IAM_POLICY_NAME" \
        --policy-document "$IAM_POLICY_JSON" \
        --description "Policy for Snowflake Iceberg access to mantra recitation bucket"
    print_status "Created IAM policy: $IAM_POLICY_NAME"
fi

# Step 7: Create IAM Role for Snowflake
echo ""
echo "Step 7: Creating IAM role for Snowflake..."

# Trust policy for Snowflake (you'll need to update this with Snowflake's account ID)
TRUST_POLICY='{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::'$AWS_ACCOUNT_ID':root"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                    "sts:ExternalId": "'$EXTERNAL_ID'"
                }
            }
        }
    ]
}'

# Create IAM role
if aws iam get-role --role-name "$IAM_ROLE_NAME" >/dev/null 2>&1; then
    print_warning "IAM role $IAM_ROLE_NAME already exists"
    # Update trust policy
    aws iam update-assume-role-policy \
        --role-name "$IAM_ROLE_NAME" \
        --policy-document "$TRUST_POLICY"
    print_status "Updated trust policy for existing role"
else
    aws iam create-role \
        --role-name "$IAM_ROLE_NAME" \
        --assume-role-policy-document "$TRUST_POLICY" \
        --description "Role for Snowflake to access Iceberg data in S3"
    print_status "Created IAM role: $IAM_ROLE_NAME"
fi

# Attach policy to role
aws iam attach-role-policy \
    --role-name "$IAM_ROLE_NAME" \
    --policy-arn "arn:aws:iam::$AWS_ACCOUNT_ID:policy/$IAM_POLICY_NAME"
print_status "Attached policy to role"

# Step 8: Create Secure Bucket Policy
echo ""
echo "Step 8: Creating secure bucket policy..."

BUCKET_POLICY='{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "DenyInsecureConnections",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::'$BUCKET_NAME'",
                "arn:aws:s3:::'$BUCKET_NAME'/*"
            ],
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "false"
                }
            }
        },
        {
            "Sid": "DenyPublicReadAccess",
            "Effect": "Deny",
            "Principal": "*",
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion"
            ],
            "Resource": "arn:aws:s3:::'$BUCKET_NAME'/*"
        },
        {
            "Sid": "AllowSnowflakeRoleAccess",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::'$AWS_ACCOUNT_ID':role/'$IAM_ROLE_NAME'"
            },
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket",
                "s3:GetBucketLocation",
                "s3:ListBucketMultipartUploads",
                "s3:ListMultipartUploadParts"
            ],
            "Resource": [
                "arn:aws:s3:::'$BUCKET_NAME'",
                "arn:aws:s3:::'$BUCKET_NAME'/*"
            ]
        }
    ]
}'

aws s3api put-bucket-policy \
    --bucket "$BUCKET_NAME" \
    --policy "$BUCKET_POLICY"
print_status "Applied secure bucket policy"

# Step 9: Create folder structure
echo ""
echo "Step 9: Creating Iceberg folder structure..."
aws s3api put-object --bucket "$BUCKET_NAME" --key "iceberg/"
aws s3api put-object --bucket "$BUCKET_NAME" --key "iceberg/mantras/"
aws s3api put-object --bucket "$BUCKET_NAME" --key "iceberg/recitations/"
aws s3api put-object --bucket "$BUCKET_NAME" --key "iceberg/users/"
print_status "Created Iceberg folder structure"

# Step 10: Verify Security Settings
echo ""
echo "Step 10: Verifying security settings..."

# Check public access block
PUBLIC_ACCESS=$(aws s3api get-public-access-block --bucket "$BUCKET_NAME" --query 'PublicAccessBlockConfiguration' --output json)
echo "Public Access Block: $PUBLIC_ACCESS"

# Check encryption
ENCRYPTION=$(aws s3api get-bucket-encryption --bucket "$BUCKET_NAME" --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' --output text)
print_status "Encryption: $ENCRYPTION"

# Check versioning
VERSIONING=$(aws s3api get-bucket-versioning --bucket "$BUCKET_NAME" --query 'Status' --output text)
print_status "Versioning: $VERSIONING"

echo ""
echo -e "${GREEN}🎉 SETUP COMPLETE! 🎉${NC}"
echo "================================"
echo ""
echo "📋 Configuration Summary:"
echo "------------------------"
echo "Bucket Name: $BUCKET_NAME"
echo "Region: $AWS_REGION"
echo "IAM Role ARN: arn:aws:iam::$AWS_ACCOUNT_ID:role/$IAM_ROLE_NAME"
echo "External ID: $EXTERNAL_ID"
echo "Logging Bucket: $LOGGING_BUCKET"
echo ""
echo "🔐 Security Features Applied:"
echo "----------------------------"
echo "✅ All public access blocked"
echo "✅ AES-256 encryption enabled"
echo "✅ Versioning enabled"
echo "✅ HTTPS-only policy enforced"
echo "✅ Access logging enabled"
echo "✅ Secure bucket policy applied"
echo "✅ Dedicated IAM role created"
echo ""
echo "📝 Next Steps:"
echo "--------------"
echo "1. Save this information securely:"
echo "   - Bucket Name: $BUCKET_NAME"
echo "   - IAM Role ARN: arn:aws:iam::$AWS_ACCOUNT_ID:role/$IAM_ROLE_NAME"
echo "   - External ID: $EXTERNAL_ID"
echo ""
echo "2. Use these values in your Snowflake external volume setup:"
echo ""
echo "CREATE OR REPLACE EXTERNAL VOLUME iceberg_storage_volume"
echo "STORAGE_LOCATIONS = ("
echo "    ("
echo "        NAME = 'mantra-private-storage'"
echo "        STORAGE_PROVIDER = 'S3'"
echo "        STORAGE_BASE_URL = 's3://$BUCKET_NAME/iceberg/'"
echo "        STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::$AWS_ACCOUNT_ID:role/$IAM_ROLE_NAME'"
echo "        STORAGE_AWS_EXTERNAL_ID = '$EXTERNAL_ID'"
echo "    )"
echo ")"
echo "COMMENT = 'Private secure storage for mantra recitation data';"
echo ""
echo "3. Run the security validation script to verify everything is secure"
echo ""

# Save configuration to file
CONFIG_FILE="aws-bucket-config.txt"
cat > "$CONFIG_FILE" << EOF
# AWS S3 Bucket Configuration for Mantra Recitation App
# Generated on: $(date)

BUCKET_NAME=$BUCKET_NAME
AWS_REGION=$AWS_REGION
AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID
IAM_ROLE_NAME=$IAM_ROLE_NAME
IAM_ROLE_ARN=arn:aws:iam::$AWS_ACCOUNT_ID:role/$IAM_ROLE_NAME
EXTERNAL_ID=$EXTERNAL_ID
LOGGING_BUCKET=$LOGGING_BUCKET

# Snowflake External Volume SQL:
CREATE OR REPLACE EXTERNAL VOLUME iceberg_storage_volume
STORAGE_LOCATIONS = (
    (
        NAME = 'mantra-private-storage'
        STORAGE_PROVIDER = 'S3'
        STORAGE_BASE_URL = 's3://$BUCKET_NAME/iceberg/'
        STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::$AWS_ACCOUNT_ID:role/$IAM_ROLE_NAME'
        STORAGE_AWS_EXTERNAL_ID = '$EXTERNAL_ID'
    )
)
COMMENT = 'Private secure storage for mantra recitation data';
EOF

print_status "Configuration saved to: $CONFIG_FILE"
print_warning "Keep this file secure - it contains sensitive information!"

echo ""
print_status "Your S3 bucket is now secure and ready for Snowflake integration! 🚀"