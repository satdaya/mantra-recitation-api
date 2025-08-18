# 🚀 AWS CLI Setup Guide for Mantra Recitation App

This guide provides comprehensive AWS CLI scripts to set up your secure S3 bucket and Snowflake integration with **maximum security** and **zero public access**.

## 📋 Prerequisites

1. **AWS CLI installed and configured**:
   ```bash
   aws configure
   # Enter your AWS Access Key ID, Secret, Region, and output format
   ```

2. **Required permissions**: Your AWS user needs permissions for:
   - S3 (create/manage buckets)
   - IAM (create/manage roles and policies)
   - STS (assume role operations)

3. **jq installed** (for JSON parsing):
   ```bash
   # macOS
   brew install jq
   
   # Ubuntu/Debian
   sudo apt-get install jq
   ```

## 🔐 Step 1: Complete Bucket Setup (Recommended)

Run the comprehensive setup script that creates everything you need:

```bash
./scripts/setup-aws-bucket.sh
```

This script will:
- ✅ Create a private S3 bucket with unique name
- ✅ **Block ALL public access** (most critical!)
- ✅ Enable AES-256 server-side encryption
- ✅ Enable versioning for data protection
- ✅ Set up access logging for security monitoring
- ✅ Create IAM role and policy with minimal permissions
- ✅ Apply secure bucket policy that denies public access
- ✅ Create proper folder structure for Iceberg
- ✅ Validate all security settings
- ✅ Generate Snowflake integration SQL

**Example output:**
```
🔐 Secure S3 Bucket Setup for Mantra Recitation App
===============================================

✅ Created bucket: mantra-recitation-private-1642547891
✅ Blocked all public access to bucket
✅ Enabled AES-256 server-side encryption
✅ Enabled bucket versioning
✅ Created IAM policy: SnowflakeIcebergPolicy
✅ Created IAM role: SnowflakeIcebergRole
✅ Applied secure bucket policy

📋 Configuration Summary:
Bucket Name: mantra-recitation-private-1642547891
IAM Role ARN: arn:aws:iam::123456789012:role/SnowflakeIcebergRole
External ID: abc123def456789...
```

## 🔍 Step 2: Validate Security

Verify your bucket meets all security requirements:

```bash
./scripts/validate-aws-security.sh YOUR-BUCKET-NAME
```

**Example:**
```bash
./scripts/validate-aws-security.sh mantra-recitation-private-1642547891
```

This will check:
- ✅ Public access block settings
- ✅ Encryption configuration
- ✅ Versioning status
- ✅ Bucket policy security
- ✅ Logging configuration
- ✅ Website configuration (should not exist)
- ✅ CORS configuration (should be minimal)

**Target: 90%+ security score**

## 🔗 Step 3: Update for Snowflake Integration

After setting up your Snowflake account, update the trust policy:

```bash
./scripts/update-snowflake-trust-policy.sh IAM-ROLE-NAME EXTERNAL-ID [SNOWFLAKE-AWS-ACCOUNT]
```

**Example:**
```bash
./scripts/update-snowflake-trust-policy.sh SnowflakeIcebergRole abc123def456
```

To get your Snowflake AWS account ID, run this in Snowflake:
```sql
SELECT SYSTEM$GET_AWS_SNS_IAM_POLICY('your-external-id');
```

## 🛠️ Manual AWS CLI Commands (Alternative)

If you prefer to run commands manually:

### Create Bucket
```bash
BUCKET_NAME="mantra-recitation-private-$(date +%s)"
aws s3 mb "s3://$BUCKET_NAME" --region us-east-1
```

### Block Public Access (CRITICAL!)
```bash
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### Enable Encryption
```bash
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'
```

### Enable Versioning
```bash
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled
```

### Create IAM Policy
```bash
cat > snowflake-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::YOUR-BUCKET-NAME",
                "arn:aws:s3:::YOUR-BUCKET-NAME/*"
            ]
        }
    ]
}
EOF

aws iam create-policy \
    --policy-name SnowflakeIcebergPolicy \
    --policy-document file://snowflake-policy.json
```

### Create IAM Role
```bash
cat > trust-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::YOUR-AWS-ACCOUNT:root"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                    "sts:ExternalId": "your-external-id"
                }
            }
        }
    ]
}
EOF

aws iam create-role \
    --role-name SnowflakeIcebergRole \
    --assume-role-policy-document file://trust-policy.json
```

### Attach Policy to Role
```bash
aws iam attach-role-policy \
    --role-name SnowflakeIcebergRole \
    --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/SnowflakeIcebergPolicy"
```

## 🧹 Cleanup (When Needed)

To safely remove all resources:

```bash
./scripts/cleanup-aws-bucket.sh BUCKET-NAME [IAM-ROLE-NAME] [IAM-POLICY-NAME]
```

**Example:**
```bash
./scripts/cleanup-aws-bucket.sh mantra-recitation-private-1642547891 SnowflakeIcebergRole SnowflakeIcebergPolicy
```

**⚠️ Warning:** This permanently deletes all data and resources!

## 🔐 Security Checklist

Before using in production, ensure:

- [ ] **Public access block enabled** (`BlockPublicAcls=true`, etc.)
- [ ] **Server-side encryption enabled** (AES-256 or KMS)
- [ ] **Versioning enabled** for data protection
- [ ] **Secure bucket policy applied** (denies public access)
- [ ] **IAM role has minimal permissions** (only required S3 actions)
- [ ] **External ID is unique and secure**
- [ ] **Access logging enabled** (optional but recommended)
- [ ] **Security validation passes** (90%+ score)
- [ ] **No website configuration** (makes bucket public)
- [ ] **CORS configuration minimal** (if any)

## 📊 Monitoring and Maintenance

### Regular Security Checks
```bash
# Run monthly security validation
./scripts/validate-aws-security.sh YOUR-BUCKET-NAME

# Check bucket public access status
aws s3api get-public-access-block --bucket YOUR-BUCKET-NAME

# Review bucket policy
aws s3api get-bucket-policy --bucket YOUR-BUCKET-NAME

# Check encryption status
aws s3api get-bucket-encryption --bucket YOUR-BUCKET-NAME
```

### Monitor Access Logs
```bash
# List recent access logs
aws s3 ls s3://YOUR-BUCKET-NAME-logs/access-logs/ --recursive

# Download recent logs for analysis
aws s3 sync s3://YOUR-BUCKET-NAME-logs/access-logs/ ./logs/
```

## 🚨 Emergency Response

If you suspect a security breach:

1. **Immediately block public access:**
   ```bash
   aws s3api put-public-access-block --bucket YOUR-BUCKET-NAME \
     --public-access-block-configuration \
     "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
   ```

2. **Review recent access:**
   ```bash
   aws s3api get-bucket-policy --bucket YOUR-BUCKET-NAME
   aws logs filter-log-events --log-group-name aws-s3-access-logs
   ```

3. **Rotate credentials:**
   - Change AWS access keys
   - Update Snowflake integration
   - Generate new external ID

## 📞 Support

- Review security validation output for specific recommendations
- Check AWS S3 security best practices documentation  
- Run `./scripts/validate-aws-security.sh BUCKET-NAME` for detailed security analysis

## 🎯 Key Benefits of This Setup

1. **Maximum Security**: All public access blocked at multiple levels
2. **Encryption**: All data encrypted at rest
3. **Auditing**: Access logs capture all activity
4. **Minimal Permissions**: IAM role has only required permissions
5. **Validation**: Automated security checks ensure compliance
6. **Easy Cleanup**: Safe removal scripts when needed
7. **Snowflake Ready**: Configured for seamless integration

Your S3 bucket will be **completely private** and secure for production use! 🔐✨