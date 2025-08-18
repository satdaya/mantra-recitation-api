#!/bin/bash

# 🔍 AWS S3 Bucket Security Validation Script
# Validates that your S3 bucket follows security best practices

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}$1${NC}"
    echo "$(printf '=%.0s' {1..50})"
}

print_pass() {
    echo -e "${GREEN}✅ PASS: $1${NC}"
}

print_fail() {
    echo -e "${RED}❌ FAIL: $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  WARNING: $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  INFO: $1${NC}"
}

# Check if bucket name is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <bucket-name>"
    echo "Example: $0 mantra-recitation-private-123456789"
    exit 1
fi

BUCKET_NAME="$1"
SECURITY_SCORE=0
TOTAL_CHECKS=0
CRITICAL_ISSUES=()
WARNINGS=()

print_header "🔐 AWS S3 Security Validation for: $BUCKET_NAME"
echo ""

# Check if AWS CLI is configured
print_info "Checking AWS CLI configuration..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    print_fail "AWS CLI not configured. Please run 'aws configure' first."
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_pass "Connected to AWS Account: $AWS_ACCOUNT_ID"
echo ""

# Check 1: Bucket exists
print_header "📦 Checking Bucket Existence"
((TOTAL_CHECKS++))
if aws s3 ls "s3://$BUCKET_NAME" >/dev/null 2>&1; then
    print_pass "Bucket exists and is accessible"
    ((SECURITY_SCORE++))
else
    print_fail "Bucket does not exist or is not accessible"
    CRITICAL_ISSUES+=("Bucket $BUCKET_NAME does not exist or is not accessible")
    exit 1
fi
echo ""

# Check 2: Public Access Block Settings
print_header "🚫 Checking Public Access Block Settings"
((TOTAL_CHECKS++))
PUBLIC_ACCESS_BLOCK=$(aws s3api get-public-access-block --bucket "$BUCKET_NAME" --output json 2>/dev/null || echo "null")

if [ "$PUBLIC_ACCESS_BLOCK" = "null" ]; then
    print_fail "No public access block configuration found"
    CRITICAL_ISSUES+=("Public access block not configured")
else
    BLOCK_PUBLIC_ACLS=$(echo "$PUBLIC_ACCESS_BLOCK" | jq -r '.PublicAccessBlockConfiguration.BlockPublicAcls // false')
    IGNORE_PUBLIC_ACLS=$(echo "$PUBLIC_ACCESS_BLOCK" | jq -r '.PublicAccessBlockConfiguration.IgnorePublicAcls // false')
    BLOCK_PUBLIC_POLICY=$(echo "$PUBLIC_ACCESS_BLOCK" | jq -r '.PublicAccessBlockConfiguration.BlockPublicPolicy // false')
    RESTRICT_PUBLIC_BUCKETS=$(echo "$PUBLIC_ACCESS_BLOCK" | jq -r '.PublicAccessBlockConfiguration.RestrictPublicBuckets // false')
    
    if [ "$BLOCK_PUBLIC_ACLS" = "true" ] && [ "$IGNORE_PUBLIC_ACLS" = "true" ] && 
       [ "$BLOCK_PUBLIC_POLICY" = "true" ] && [ "$RESTRICT_PUBLIC_BUCKETS" = "true" ]; then
        print_pass "All public access is blocked"
        ((SECURITY_SCORE++))
    else
        print_fail "Public access is not fully blocked"
        CRITICAL_ISSUES+=("Public access block settings are not complete")
        echo "  BlockPublicAcls: $BLOCK_PUBLIC_ACLS"
        echo "  IgnorePublicAcls: $IGNORE_PUBLIC_ACLS"
        echo "  BlockPublicPolicy: $BLOCK_PUBLIC_POLICY"
        echo "  RestrictPublicBuckets: $RESTRICT_PUBLIC_BUCKETS"
    fi
fi
echo ""

# Check 3: Encryption Settings
print_header "🔐 Checking Encryption Settings"
((TOTAL_CHECKS++))
ENCRYPTION=$(aws s3api get-bucket-encryption --bucket "$BUCKET_NAME" --output json 2>/dev/null || echo "null")

if [ "$ENCRYPTION" = "null" ]; then
    print_fail "Server-side encryption is not enabled"
    CRITICAL_ISSUES+=("Server-side encryption not configured")
else
    SSE_ALGORITHM=$(echo "$ENCRYPTION" | jq -r '.ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm // "none"')
    if [ "$SSE_ALGORITHM" != "none" ]; then
        print_pass "Server-side encryption enabled ($SSE_ALGORITHM)"
        ((SECURITY_SCORE++))
    else
        print_fail "Server-side encryption algorithm not found"
        CRITICAL_ISSUES+=("Invalid encryption configuration")
    fi
fi
echo ""

# Check 4: Versioning
print_header "📄 Checking Versioning Settings"
((TOTAL_CHECKS++))
VERSIONING=$(aws s3api get-bucket-versioning --bucket "$BUCKET_NAME" --query 'Status' --output text 2>/dev/null || echo "None")

if [ "$VERSIONING" = "Enabled" ]; then
    print_pass "Bucket versioning is enabled"
    ((SECURITY_SCORE++))
elif [ "$VERSIONING" = "Suspended" ]; then
    print_warning "Bucket versioning is suspended"
    WARNINGS+=("Versioning is suspended - consider enabling for data protection")
else
    print_warning "Bucket versioning is not enabled"
    WARNINGS+=("Versioning not enabled - recommended for data protection")
fi
echo ""

# Check 5: Bucket Policy
print_header "📜 Checking Bucket Policy"
((TOTAL_CHECKS++))
BUCKET_POLICY=$(aws s3api get-bucket-policy --bucket "$BUCKET_NAME" --output json 2>/dev/null || echo "null")

if [ "$BUCKET_POLICY" = "null" ]; then
    print_warning "No bucket policy found"
    WARNINGS+=("No bucket policy configured")
else
    # Check if policy denies insecure transport
    DENIES_HTTP=$(echo "$BUCKET_POLICY" | jq -r '.Policy | fromjson | .Statement[] | select(.Effect=="Deny" and (.Condition.Bool."aws:SecureTransport"=="false" or .Condition.Bool."aws:SecureTransport"==false)) | .Effect' 2>/dev/null || echo "")
    
    if [ "$DENIES_HTTP" = "Deny" ]; then
        print_pass "Bucket policy enforces HTTPS-only access"
        ((SECURITY_SCORE++))
    else
        print_warning "Bucket policy doesn't enforce HTTPS-only access"
        WARNINGS+=("Bucket policy should deny insecure HTTP connections")
    fi
    
    # Check for public read/write denial
    DENIES_PUBLIC_READ=$(echo "$BUCKET_POLICY" | jq -r '.Policy | fromjson | .Statement[] | select(.Effect=="Deny" and (.Action | contains(["s3:GetObject"]) or . == "s3:GetObject")) | .Effect' 2>/dev/null || echo "")
    
    if [ "$DENIES_PUBLIC_READ" = "Deny" ]; then
        print_pass "Bucket policy denies public read access"
    else
        print_warning "Bucket policy should explicitly deny public read access"
        WARNINGS+=("Add explicit denial of public read access to bucket policy")
    fi
fi
echo ""

# Check 6: Logging Configuration
print_header "📊 Checking Access Logging"
((TOTAL_CHECKS++))
LOGGING=$(aws s3api get-bucket-logging --bucket "$BUCKET_NAME" --output json 2>/dev/null || echo "null")

if [ "$LOGGING" = "null" ] || [ "$(echo "$LOGGING" | jq -r '.LoggingEnabled // "null"')" = "null" ]; then
    print_warning "Access logging is not configured"
    WARNINGS+=("Consider enabling access logging for security monitoring")
else
    TARGET_BUCKET=$(echo "$LOGGING" | jq -r '.LoggingEnabled.TargetBucket')
    print_pass "Access logging enabled (logs to: $TARGET_BUCKET)"
    ((SECURITY_SCORE++))
fi
echo ""

# Check 7: Lifecycle Configuration (Optional but recommended)
print_header "♻️  Checking Lifecycle Configuration"
((TOTAL_CHECKS++))
LIFECYCLE=$(aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET_NAME" --output json 2>/dev/null || echo "null")

if [ "$LIFECYCLE" = "null" ]; then
    print_info "No lifecycle configuration found (optional)"
    WARNINGS+=("Consider adding lifecycle rules to manage storage costs")
else
    print_pass "Lifecycle configuration is set"
    ((SECURITY_SCORE++))
fi
echo ""

# Check 8: CORS Configuration
print_header "🌐 Checking CORS Configuration"
((TOTAL_CHECKS++))
CORS=$(aws s3api get-bucket-cors --bucket "$BUCKET_NAME" --output json 2>/dev/null || echo "null")

if [ "$CORS" = "null" ]; then
    print_pass "No CORS configuration (good for security)"
    ((SECURITY_SCORE++))
else
    print_warning "CORS configuration found - review for security implications"
    WARNINGS+=("Review CORS configuration to ensure it's not overly permissive")
    echo "CORS Rules: $CORS"
fi
echo ""

# Check 9: Website Configuration (Should not exist)
print_header "🌍 Checking Website Configuration"
((TOTAL_CHECKS++))
WEBSITE=$(aws s3api get-bucket-website --bucket "$BUCKET_NAME" --output json 2>/dev/null || echo "null")

if [ "$WEBSITE" = "null" ]; then
    print_pass "No website configuration (good for security)"
    ((SECURITY_SCORE++))
else
    print_fail "Website configuration found - this makes bucket public!"
    CRITICAL_ISSUES+=("Website configuration detected - this exposes bucket publicly")
fi
echo ""

# Check 10: Notification Configuration
print_header "🔔 Checking Notification Configuration"
((TOTAL_CHECKS++))
NOTIFICATIONS=$(aws s3api get-bucket-notification-configuration --bucket "$BUCKET_NAME" --output json 2>/dev/null || echo "{}")

if [ "$NOTIFICATIONS" = "{}" ]; then
    print_info "No notification configuration (neutral)"
else
    print_info "Notification configuration found"
    echo "Notifications: $NOTIFICATIONS"
fi
((SECURITY_SCORE++))  # Neutral check
echo ""

# Generate Security Report
print_header "📋 SECURITY ASSESSMENT REPORT"

SECURITY_PERCENTAGE=$((SECURITY_SCORE * 100 / TOTAL_CHECKS))

echo "Bucket: $BUCKET_NAME"
echo "Assessment Date: $(date)"
echo "Security Score: $SECURITY_SCORE/$TOTAL_CHECKS ($SECURITY_PERCENTAGE%)"
echo ""

if [ $SECURITY_PERCENTAGE -ge 90 ]; then
    echo -e "${GREEN}🎉 EXCELLENT SECURITY POSTURE${NC}"
    echo "Your bucket follows security best practices!"
elif [ $SECURITY_PERCENTAGE -ge 75 ]; then
    echo -e "${YELLOW}👍 GOOD SECURITY POSTURE${NC}"
    echo "Minor improvements recommended."
elif [ $SECURITY_PERCENTAGE -ge 60 ]; then
    echo -e "${YELLOW}⚠️  ACCEPTABLE SECURITY${NC}"
    echo "Several improvements needed."
else
    echo -e "${RED}🚨 CRITICAL SECURITY ISSUES${NC}"
    echo "Immediate action required!"
fi

echo ""

if [ ${#CRITICAL_ISSUES[@]} -gt 0 ]; then
    echo -e "${RED}🚨 CRITICAL ISSUES TO FIX:${NC}"
    for issue in "${CRITICAL_ISSUES[@]}"; do
        echo "  ❌ $issue"
    done
    echo ""
fi

if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  WARNINGS AND RECOMMENDATIONS:${NC}"
    for warning in "${WARNINGS[@]}"; do
        echo "  ⚠️  $warning"
    done
    echo ""
fi

# Remediation suggestions
if [ ${#CRITICAL_ISSUES[@]} -gt 0 ] || [ ${#WARNINGS[@]} -gt 0 ]; then
    print_header "🔧 REMEDIATION SUGGESTIONS"
    
    echo "To fix critical issues:"
    echo ""
    echo "1. Enable public access block:"
    echo "   aws s3api put-public-access-block --bucket $BUCKET_NAME \\"
    echo "     --public-access-block-configuration \\"
    echo "     'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'"
    echo ""
    echo "2. Enable encryption:"
    echo "   aws s3api put-bucket-encryption --bucket $BUCKET_NAME \\"
    echo "     --server-side-encryption-configuration '{"
    echo "       \"Rules\": [{"
    echo "         \"ApplyServerSideEncryptionByDefault\": {"
    echo "           \"SSEAlgorithm\": \"AES256\""
    echo "         }"
    echo "       }]"
    echo "     }'"
    echo ""
    echo "3. Enable versioning:"
    echo "   aws s3api put-bucket-versioning --bucket $BUCKET_NAME \\"
    echo "     --versioning-configuration Status=Enabled"
    echo ""
    echo "4. Apply secure bucket policy (see setup script)"
    echo ""
fi

# Summary and exit code
echo ""
if [ ${#CRITICAL_ISSUES[@]} -eq 0 ]; then
    print_pass "Security validation completed successfully! ✨"
    exit 0
else
    print_fail "Security validation found critical issues that must be addressed!"
    exit 1
fi