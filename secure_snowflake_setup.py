"""
Secure Snowflake setup script with bucket privacy validation
Run this script to validate your Snowflake security configuration
"""

import os
import sys
from typing import Dict, Any

# Add the app directory to Python path
sys.path.append(os.path.join(os.path.dirname(__file__), 'app'))

from app.core.database import SnowflakeConnection
from app.services.security_validator import SecurityValidator


def main():
    """
    Main security validation function
    """
    print("🔐 SNOWFLAKE SECURITY VALIDATION")
    print("=" * 50)
    print()
    
    # Check environment variables
    required_env_vars = [
        'SNOWFLAKE_ACCOUNT',
        'SNOWFLAKE_USER', 
        'SNOWFLAKE_PASSWORD',
        'SNOWFLAKE_DATABASE',
        'SNOWFLAKE_SCHEMA',
        'SNOWFLAKE_WAREHOUSE'
    ]
    
    missing_vars = [var for var in required_env_vars if not os.getenv(var)]
    
    if missing_vars:
        print("❌ MISSING ENVIRONMENT VARIABLES:")
        for var in missing_vars:
            print(f"   - {var}")
        print("\nPlease set these environment variables and try again.")
        print("You can copy .env.example to .env and fill in your values.")
        return False
    
    print("✅ All required environment variables are set")
    print()
    
    # Test Snowflake connection
    print("🔌 Testing Snowflake connection...")
    db = SnowflakeConnection()
    
    try:
        connection = db.connect()
        print("✅ Successfully connected to Snowflake")
        
        # Run bucket security validation
        print("\n🛡️  Validating bucket security...")
        bucket_security = db.validate_bucket_security()
        
        print("Bucket Security Results:")
        for check, passed in bucket_security.items():
            status = "✅ PASS" if passed else "❌ FAIL"
            print(f"   {check}: {status}")
        
        # Run comprehensive security audit
        print("\n🔍 Running comprehensive security audit...")
        validator = SecurityValidator(db)
        audit_results = validator.run_comprehensive_security_audit()
        
        print(f"\nSecurity Score: {audit_results['security_score']}/100")
        print(f"Overall Status: {audit_results['overall_status']}")
        
        # Display detailed results
        print("\nDetailed Security Checks:")
        for check_name, check_result in audit_results['checks'].items():
            status = check_result.get('status', 'UNKNOWN')
            emoji = get_status_emoji(status)
            print(f"   {emoji} {check_name.replace('_', ' ').title()}: {status}")
            
            # Show critical issues
            if check_result.get('issues'):
                for issue in check_result['issues'][:3]:  # Show first 3 issues
                    print(f"      ⚠️  {issue}")
        
        # Critical issues summary
        if audit_results.get('critical_issues'):
            print("\n🚨 CRITICAL ISSUES FOUND:")
            for issue in audit_results['critical_issues']:
                print(f"   - {issue}")
        
        # Generate full security report
        print("\n📄 Generating full security report...")
        report = validator.generate_security_report()
        
        # Save report to file
        report_file = "snowflake_security_report.txt"
        with open(report_file, 'w') as f:
            f.write(report)
        
        print(f"✅ Full security report saved to: {report_file}")
        
        # Recommendations based on score
        provide_recommendations(audit_results['security_score'])
        
        return audit_results['security_score'] >= 75
        
    except Exception as e:
        print(f"❌ Error connecting to Snowflake: {e}")
        print("\nTroubleshooting tips:")
        print("1. Verify your Snowflake account URL format")
        print("2. Check your username and password")
        print("3. Ensure your IP is whitelisted if network policies are enabled")
        print("4. Verify the database and warehouse exist")
        return False
    
    finally:
        db.close()


def get_status_emoji(status: str) -> str:
    """Get emoji for status"""
    emoji_map = {
        'PASS': '✅',
        'FAIL': '❌', 
        'WARNING': '⚠️',
        'ERROR': '🔴',
        'UNKNOWN': '❓'
    }
    return emoji_map.get(status, '❓')


def provide_recommendations(security_score: int):
    """Provide security recommendations based on score"""
    print(f"\n💡 RECOMMENDATIONS:")
    
    if security_score >= 90:
        print("   🎉 Excellent security posture! Your setup is well-secured.")
        print("   Consider periodic security audits to maintain this level.")
    elif security_score >= 75:
        print("   👍 Good security setup with minor improvements needed.")
        print("   Review the warnings above and address when possible.")
    elif security_score >= 60:
        print("   ⚠️  Acceptable security but improvements strongly recommended.")
        print("   Address the failed checks to improve your security posture.")
    else:
        print("   🚨 CRITICAL: Your setup has significant security risks!")
        print("   Address all failed checks before using in production.")
    
    print("\nGeneral Security Best Practices:")
    print("   1. Use dedicated IAM roles with minimal required permissions")
    print("   2. Enable S3 bucket encryption and block public access")
    print("   3. Implement network policies to restrict IP access")
    print("   4. Regularly rotate passwords and access keys")
    print("   5. Monitor query history and access logs")
    print("   6. Use separate environments for dev/staging/production")


def create_secure_bucket_policy():
    """
    Generate a secure S3 bucket policy template
    """
    policy_template = """
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "DenyPublicAccess",
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
            "Sid": "AllowSnowflakeAccess",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::YOUR-ACCOUNT:role/SnowflakeIcebergRole"
            },
            "Action": [
                "s3:GetObject",
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
"""
    
    print("\n📋 SECURE S3 BUCKET POLICY TEMPLATE:")
    print("Save this as your bucket policy (replace YOUR-BUCKET-NAME and YOUR-ACCOUNT):")
    print(policy_template)


if __name__ == "__main__":
    print("Starting Snowflake security validation...")
    
    success = main()
    
    if success:
        print("\n🎉 Security validation completed successfully!")
        print("Your Snowflake setup meets security requirements.")
    else:
        print("\n⚠️  Security validation found issues.")
        print("Please address the issues above before proceeding.")
        sys.exit(1)
        
    print("\n🔒 For additional security, run this validation regularly!")