"""
Security validation service for Snowflake and storage buckets
"""

import logging
from typing import Dict, List, Any
from ..core.database import SnowflakeConnection

logger = logging.getLogger(__name__)


class SecurityValidator:
    """
    Validates security configurations for Snowflake and storage
    """
    
    def __init__(self, db_connection: SnowflakeConnection):
        self.db = db_connection
        
    def run_comprehensive_security_audit(self) -> Dict[str, Any]:
        """
        Run comprehensive security audit on Snowflake setup
        """
        audit_results = {
            "timestamp": self._get_current_timestamp(),
            "overall_status": "UNKNOWN",
            "security_score": 0,
            "checks": {
                "storage_security": self._validate_storage_security(),
                "network_security": self._validate_network_security(),
                "access_controls": self._validate_access_controls(),
                "encryption": self._validate_encryption(),
                "monitoring": self._validate_monitoring_setup()
            },
            "recommendations": [],
            "critical_issues": []
        }
        
        # Calculate overall security score
        total_checks = len(audit_results["checks"])
        passed_checks = sum(1 for check in audit_results["checks"].values() 
                          if check.get("status") == "PASS")
        
        audit_results["security_score"] = int((passed_checks / total_checks) * 100)
        
        # Determine overall status
        if audit_results["security_score"] >= 90:
            audit_results["overall_status"] = "EXCELLENT"
        elif audit_results["security_score"] >= 75:
            audit_results["overall_status"] = "GOOD"
        elif audit_results["security_score"] >= 60:
            audit_results["overall_status"] = "ACCEPTABLE"
        else:
            audit_results["overall_status"] = "CRITICAL"
            
        return audit_results
    
    def _validate_storage_security(self) -> Dict[str, Any]:
        """
        Validate storage bucket security settings
        """
        result = {
            "status": "UNKNOWN",
            "details": {},
            "issues": []
        }
        
        try:
            if not self.db.connection:
                self.db.connect()
                
            cursor = self.db.connection.cursor()
            
            # Check external volumes
            cursor.execute("""
                SELECT volume_name, storage_base_url, 
                       storage_aws_role_arn, comment
                FROM information_schema.external_volumes
                WHERE database_name = %s
            """, (self.db.get_connection_params()['database'],))
            
            volumes = cursor.fetchall()
            
            if not volumes:
                result["issues"].append("No external volumes found - data may not be properly secured")
                result["status"] = "WARNING"
            else:
                secure_volumes = 0
                for volume in volumes:
                    volume_name = volume[0]
                    storage_url = volume[1] or ""
                    role_arn = volume[2] or ""
                    
                    volume_security = self._analyze_volume_security(
                        volume_name, storage_url, role_arn
                    )
                    
                    result["details"][volume_name] = volume_security
                    
                    if volume_security["is_secure"]:
                        secure_volumes += 1
                    else:
                        result["issues"].extend(volume_security["issues"])
                
                if secure_volumes == len(volumes):
                    result["status"] = "PASS"
                elif secure_volumes > 0:
                    result["status"] = "WARNING"
                else:
                    result["status"] = "FAIL"
            
            cursor.close()
            
        except Exception as e:
            logger.error(f"Error validating storage security: {e}")
            result["status"] = "ERROR"
            result["issues"].append(f"Failed to validate storage: {str(e)}")
        
        return result
    
    def _analyze_volume_security(self, volume_name: str, storage_url: str, 
                                role_arn: str) -> Dict[str, Any]:
        """
        Analyze security of a specific volume
        """
        analysis = {
            "is_secure": True,
            "issues": [],
            "recommendations": []
        }
        
        # Check storage URL security
        if not storage_url:
            analysis["is_secure"] = False
            analysis["issues"].append(f"Volume {volume_name} has no storage URL")
        elif self._has_public_access_indicators(storage_url):
            analysis["is_secure"] = False
            analysis["issues"].append(f"Volume {volume_name} may have public access")
        
        # Check IAM role configuration
        if not role_arn:
            analysis["is_secure"] = False
            analysis["issues"].append(f"Volume {volume_name} has no IAM role ARN")
        elif not self._is_valid_role_arn(role_arn):
            analysis["is_secure"] = False
            analysis["issues"].append(f"Volume {volume_name} has invalid IAM role ARN")
        
        # Security recommendations
        if 's3://' in storage_url.lower():
            analysis["recommendations"].append(
                f"Ensure S3 bucket for {volume_name} has:"
                " - Block Public Access enabled"
                " - Bucket policy restricting access to Snowflake role only"
                " - Server-side encryption enabled"
                " - Versioning enabled for data protection"
            )
        
        return analysis
    
    def _has_public_access_indicators(self, storage_url: str) -> bool:
        """
        Check if storage URL has indicators of public access
        """
        public_indicators = [
            'public-read',
            'public-read-write',
            'public-bucket',
            'open-access'
        ]
        
        return any(indicator in storage_url.lower() for indicator in public_indicators)
    
    def _is_valid_role_arn(self, role_arn: str) -> bool:
        """
        Basic validation of AWS IAM role ARN format
        """
        return (role_arn.startswith('arn:aws:iam::') and 
                ':role/' in role_arn and
                len(role_arn.split(':')) == 6)
    
    def _validate_network_security(self) -> Dict[str, Any]:
        """
        Validate network security configurations
        """
        result = {
            "status": "UNKNOWN",
            "details": {},
            "issues": []
        }
        
        try:
            cursor = self.db.connection.cursor()
            
            # Check network policies
            cursor.execute("SHOW NETWORK POLICIES")
            policies = cursor.fetchall()
            
            if not policies:
                result["status"] = "WARNING"
                result["issues"].append("No network policies found - consider restricting IP access")
            else:
                result["status"] = "PASS"
                result["details"]["network_policies_count"] = len(policies)
            
            cursor.close()
            
        except Exception as e:
            logger.error(f"Error validating network security: {e}")
            result["status"] = "ERROR"
            result["issues"].append(f"Failed to validate network security: {str(e)}")
        
        return result
    
    def _validate_access_controls(self) -> Dict[str, Any]:
        """
        Validate access control configurations
        """
        result = {
            "status": "PASS",  # Assume pass unless issues found
            "details": {},
            "issues": []
        }
        
        try:
            cursor = self.db.connection.cursor()
            
            # Check current user privileges
            cursor.execute("SELECT CURRENT_ROLE(), CURRENT_USER()")
            current_info = cursor.fetchone()
            
            result["details"]["current_role"] = current_info[0]
            result["details"]["current_user"] = current_info[1]
            
            # Check if using default roles (potential security risk)
            if current_info[0] in ['ACCOUNTADMIN', 'SECURITYADMIN']:
                result["issues"].append(
                    f"Using high-privilege role {current_info[0]} - consider using least-privilege role"
                )
                result["status"] = "WARNING"
            
            cursor.close()
            
        except Exception as e:
            logger.error(f"Error validating access controls: {e}")
            result["status"] = "ERROR"
            result["issues"].append(f"Failed to validate access controls: {str(e)}")
        
        return result
    
    def _validate_encryption(self) -> Dict[str, Any]:
        """
        Validate encryption settings
        """
        result = {
            "status": "PASS",
            "details": {
                "snowflake_encryption": "Snowflake provides automatic encryption at rest and in transit"
            },
            "issues": []
        }
        
        # Snowflake automatically encrypts all data
        # Additional checks could be added for customer-managed keys
        return result
    
    def _validate_monitoring_setup(self) -> Dict[str, Any]:
        """
        Validate monitoring and auditing setup
        """
        result = {
            "status": "PASS",
            "details": {},
            "issues": []
        }
        
        try:
            cursor = self.db.connection.cursor()
            
            # Check if query history is available (indicates monitoring is working)
            cursor.execute("""
                SELECT COUNT(*) 
                FROM information_schema.query_history 
                WHERE start_time >= DATEADD(hour, -1, CURRENT_TIMESTAMP())
            """)
            
            recent_queries = cursor.fetchone()[0]
            result["details"]["recent_queries"] = recent_queries
            
            if recent_queries == 0:
                result["status"] = "WARNING"
                result["issues"].append("No recent query history found - monitoring may not be active")
            
            cursor.close()
            
        except Exception as e:
            logger.error(f"Error validating monitoring setup: {e}")
            result["status"] = "WARNING"
            result["issues"].append(f"Could not validate monitoring: {str(e)}")
        
        return result
    
    def _get_current_timestamp(self) -> str:
        """
        Get current timestamp for audit report
        """
        from datetime import datetime
        return datetime.utcnow().isoformat()
    
    def generate_security_report(self) -> str:
        """
        Generate human-readable security report
        """
        audit = self.run_comprehensive_security_audit()
        
        report = f"""
SNOWFLAKE SECURITY AUDIT REPORT
================================
Timestamp: {audit['timestamp']}
Overall Status: {audit['overall_status']}
Security Score: {audit['security_score']}/100

SECURITY CHECKS:
"""
        
        for check_name, check_result in audit['checks'].items():
            status = check_result.get('status', 'UNKNOWN')
            report += f"  {check_name.upper()}: {status}\n"
            
            if check_result.get('issues'):
                report += "    Issues:\n"
                for issue in check_result['issues']:
                    report += f"      - {issue}\n"
        
        if audit['critical_issues']:
            report += "\nCRITICAL ISSUES:\n"
            for issue in audit['critical_issues']:
                report += f"  - {issue}\n"
        
        if audit['recommendations']:
            report += "\nRECOMMENDATIONS:\n"
            for rec in audit['recommendations']:
                report += f"  - {rec}\n"
        
        return report