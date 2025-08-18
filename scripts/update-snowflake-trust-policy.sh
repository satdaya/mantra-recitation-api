#!/bin/bash

# 🔗 Update IAM Role Trust Policy for Snowflake Integration
# This script updates the trust policy with Snowflake's AWS account ID

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <iam-role-name> <external-id> [snowflake-aws-account-id]"
    echo ""
    echo "Examples:"
    echo "  $0 SnowflakeIcebergRole abc123def456 123456789012"
    echo ""
    echo "If Snowflake AWS account ID is not provided, you'll be prompted to enter it."
    echo ""
    echo "To find your Snowflake AWS account ID, run this in Snowflake:"
    echo "  SELECT SYSTEM\$GET_AWS_SNS_IAM_POLICY('<external-id>');"
    echo ""
    exit 1
fi

IAM_ROLE_NAME="$1"
EXTERNAL_ID="$2"
SNOWFLAKE_AWS_ACCOUNT_ID="$3"

echo -e "${BLUE}🔗 UPDATING SNOWFLAKE TRUST POLICY${NC}"
echo "=================================="
echo ""

# Get current AWS account info
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    print_error "AWS CLI not configured. Please run 'aws configure' first."
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_success "Connected to AWS Account: $AWS_ACCOUNT_ID"

# Check if role exists
if ! aws iam get-role --role-name "$IAM_ROLE_NAME" >/dev/null 2>&1; then
    print_error "IAM role '$IAM_ROLE_NAME' does not exist."
    exit 1
fi

print_success "IAM role '$IAM_ROLE_NAME' found"

# Get Snowflake AWS Account ID if not provided
if [ -z "$SNOWFLAKE_AWS_ACCOUNT_ID" ]; then
    echo ""
    print_info "To get your Snowflake AWS account ID:"
    echo "1. Log into your Snowflake account"
    echo "2. Run: SELECT SYSTEM\$GET_AWS_SNS_IAM_POLICY('$EXTERNAL_ID');"
    echo "3. Look for the AWS account ID in the returned policy"
    echo ""
    print_info "Common Snowflake AWS account IDs by region:"
    echo "  • US East (Virginia):     123456789012"
    echo "  • US West (Oregon):       123456789012" 
    echo "  • Europe (Ireland):       123456789012"
    echo "  • Asia Pacific (Tokyo):   123456789012"
    echo ""
    print_warning "Note: These are example IDs. Use the actual ID from your Snowflake query."
    echo ""
    
    read -p "Enter your Snowflake AWS Account ID: " SNOWFLAKE_AWS_ACCOUNT_ID
    
    if [ -z "$SNOWFLAKE_AWS_ACCOUNT_ID" ]; then
        print_error "Snowflake AWS Account ID is required."
        exit 1
    fi
fi

# Validate account ID format (12 digits)
if ! [[ "$SNOWFLAKE_AWS_ACCOUNT_ID" =~ ^[0-9]{12}$ ]]; then
    print_error "Invalid AWS Account ID format. Must be 12 digits."
    exit 1
fi

print_success "Using Snowflake AWS Account ID: $SNOWFLAKE_AWS_ACCOUNT_ID"

# Create updated trust policy
print_info "Creating updated trust policy..."

UPDATED_TRUST_POLICY='{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::'$SNOWFLAKE_AWS_ACCOUNT_ID':root"
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

# Show the policy that will be applied
echo ""
print_info "Trust policy to be applied:"
echo "$UPDATED_TRUST_POLICY" | jq .

# Confirm before applying
echo ""
read -p "Apply this trust policy? (y/N): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

# Apply the updated trust policy
print_info "Updating trust policy..."
aws iam update-assume-role-policy \
    --role-name "$IAM_ROLE_NAME" \
    --policy-document "$UPDATED_TRUST_POLICY"

print_success "Trust policy updated successfully!"

# Verify the update
echo ""
print_info "Verifying the updated trust policy..."
CURRENT_POLICY=$(aws iam get-role --role-name "$IAM_ROLE_NAME" --query 'Role.AssumeRolePolicyDocument' --output json)

echo "Current trust policy:"
echo "$CURRENT_POLICY" | jq .

# Validate the policy has correct Snowflake account ID
POLICY_ACCOUNT_ID=$(echo "$CURRENT_POLICY" | jq -r '.Statement[0].Principal.AWS' | grep -o '[0-9]\{12\}' || echo "")

if [ "$POLICY_ACCOUNT_ID" = "$SNOWFLAKE_AWS_ACCOUNT_ID" ]; then
    print_success "Trust policy verification successful!"
else
    print_warning "Trust policy verification failed. Please check manually."
fi

# Generate Snowflake SQL commands
echo ""
echo -e "${GREEN}🎉 TRUST POLICY UPDATE COMPLETED! 🎉${NC}"
echo "===================================="
echo ""
echo "Your IAM role is now ready for Snowflake integration."
echo ""
echo "📋 Next steps in Snowflake:"
echo "---------------------------"
echo ""
echo "1. Create or update your external volume:"
echo ""
echo "CREATE OR REPLACE EXTERNAL VOLUME iceberg_storage_volume"
echo "STORAGE_LOCATIONS = ("
echo "    ("
echo "        NAME = 'mantra-private-storage'"
echo "        STORAGE_PROVIDER = 'S3'"
echo "        STORAGE_BASE_URL = 's3://YOUR-BUCKET-NAME/iceberg/'"
echo "        STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::$AWS_ACCOUNT_ID:role/$IAM_ROLE_NAME'"
echo "        STORAGE_AWS_EXTERNAL_ID = '$EXTERNAL_ID'"
echo "    )"
echo ")"
echo "COMMENT = 'Private secure storage for mantra recitation data';"
echo ""
echo "2. Test the integration:"
echo ""
echo "DESC EXTERNAL VOLUME iceberg_storage_volume;"
echo ""
echo "3. Create your Iceberg tables using the SQL in snowflake_iceberg_setup.sql"
echo ""
echo "🔐 Security Summary:"
echo "-------------------"
echo "  ✅ External ID: $EXTERNAL_ID"
echo "  ✅ Snowflake Account: $SNOWFLAKE_AWS_ACCOUNT_ID"  
echo "  ✅ Your AWS Account: $AWS_ACCOUNT_ID"
echo "  ✅ IAM Role: $IAM_ROLE_NAME"
echo ""
print_success "Integration setup complete! 🚀"