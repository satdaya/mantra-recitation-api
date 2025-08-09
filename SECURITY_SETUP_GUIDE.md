# 🔐 Security Setup Guide

This guide ensures your Snowflake and storage buckets are properly secured and private.

## 🚨 CRITICAL: Ensure Buckets Are Private

### 1. AWS S3 Bucket Security Checklist

#### ✅ Required Security Settings

1. **Block Public Access** (Most Important!)
   ```bash
   # Enable all block public access settings
   aws s3api put-public-access-block \
     --bucket your-mantra-bucket \
     --public-access-block-configuration \
     "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
   ```

2. **Server-Side Encryption**
   ```bash
   aws s3api put-bucket-encryption \
     --bucket your-mantra-bucket \
     --server-side-encryption-configuration '{
       "Rules": [{
         "ApplyServerSideEncryptionByDefault": {
           "SSEAlgorithm": "AES256"
         }
       }]
     }'
   ```

3. **Bucket Versioning** (Data Protection)
   ```bash
   aws s3api put-bucket-versioning \
     --bucket your-mantra-bucket \
     --versioning-configuration Status=Enabled
   ```

#### 🔒 Secure Bucket Policy

Replace `YOUR-BUCKET-NAME` and `YOUR-AWS-ACCOUNT-ID` with your values:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "DenyInsecureConnections",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::YOUR-BUCKET-NAME",
                "arn:aws:s3:::YOUR-BUCKET-NAME/*"
            ],
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "false"
                }
            }
        },
        {
            "Sid": "DenyPublicRead",
            "Effect": "Deny",
            "Principal": "*",
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion"
            ],
            "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME/*"
        },
        {
            "Sid": "AllowSnowflakeAccess",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::YOUR-AWS-ACCOUNT-ID:role/SnowflakeIcebergRole"
            },
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
```

### 2. IAM Role Setup for Snowflake

#### Create Dedicated Role

1. **Create IAM Role** `SnowflakeIcebergRole`
2. **Attach Policy**:

```json
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
                "arn:aws:s3:::your-mantra-bucket",
                "arn:aws:s3:::your-mantra-bucket/*"
            ]
        }
    ]
}
```

3. **Trust Relationship** (Replace with your Snowflake account):

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::YOUR-SNOWFLAKE-ACCOUNT:root"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                    "sts:ExternalId": "YOUR-EXTERNAL-ID"
                }
            }
        }
    ]
}
```

## 🏗️ Snowflake Setup

### 1. Environment Variables

Copy `.env.example` to `.env` and fill in your secure values:

```bash
cp .env.example .env
```

**Critical Settings:**
- `REQUIRE_SECURE_BUCKETS=true` - Validates bucket security
- `BLOCK_PUBLIC_BUCKET_ACCESS=true` - Prevents public access
- `STORAGE_ENCRYPTION_REQUIRED=true` - Requires encryption

### 2. Create External Volume (Secure)

```sql
CREATE OR REPLACE EXTERNAL VOLUME iceberg_storage_volume
STORAGE_LOCATIONS = (
    (
        NAME = 'mantra-private-storage'
        STORAGE_PROVIDER = 'S3'
        STORAGE_BASE_URL = 's3://your-private-mantra-bucket/iceberg/'
        STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::YOUR-ACCOUNT:role/SnowflakeIcebergRole'
        STORAGE_AWS_EXTERNAL_ID = 'YOUR-EXTERNAL-ID'
    )
)
COMMENT = 'Private secure storage for mantra recitation data'
```

### 3. Security Validation

Run the security validation script:

```bash
# Activate virtual environment
source .venv/bin/activate

# Run security validation
python secure_snowflake_setup.py
```

This will:
- ✅ Test Snowflake connection
- 🔍 Validate bucket privacy settings
- 📊 Generate security score (aim for 90+)
- 📄 Create detailed security report

## 🛡️ Network Security

### Snowflake Network Policy (Optional but Recommended)

```sql
CREATE OR REPLACE NETWORK POLICY mantra_app_policy
ALLOWED_IP_LIST = (
    'YOUR.IP.ADDRESS.HERE',
    'YOUR.SERVER.IP.RANGE/24'
)
COMMENT = 'Restrict access to mantra recitation app only';

-- Apply to your user
ALTER USER your_username SET NETWORK_POLICY = mantra_app_policy;
```

## 🚨 Security Checklist

Before going to production, verify:

- [ ] **S3 Bucket has "Block Public Access" enabled**
- [ ] **Bucket policy denies public read/write**
- [ ] **Server-side encryption is enabled**
- [ ] **IAM role has minimal required permissions**
- [ ] **Snowflake uses dedicated role (not ACCOUNTADMIN)**
- [ ] **External volume uses private S3 bucket**
- [ ] **Network policies restrict IP access** (optional)
- [ ] **Security validation script passes (score 90+)**
- [ ] **No secrets in git repository**
- [ ] **Environment variables are set securely**

## 🔍 Regular Security Monitoring

### Monthly Checks

1. Run security validation script
2. Review Snowflake query history for unusual activity
3. Check S3 bucket access logs
4. Verify IAM role permissions haven't changed

### Commands for Monitoring

```bash
# Check bucket public access status
aws s3api get-public-access-block --bucket your-mantra-bucket

# Review bucket policy
aws s3api get-bucket-policy --bucket your-mantra-bucket

# Check encryption status
aws s3api get-bucket-encryption --bucket your-mantra-bucket
```

## 🆘 Emergency Response

If you suspect a security breach:

1. **Immediately block bucket access**:
   ```bash
   aws s3api put-public-access-block --bucket your-mantra-bucket \
     --public-access-block-configuration \
     "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
   ```

2. **Rotate credentials**:
   - Change Snowflake password
   - Rotate AWS IAM keys
   - Update application secrets

3. **Review access logs**:
   - Check S3 access logs
   - Review Snowflake query history
   - Check application logs

4. **Re-run security validation** after fixes

## 📞 Support

For security questions or concerns:
- Review this guide thoroughly
- Run the security validation script
- Check Snowflake and AWS security best practices documentation