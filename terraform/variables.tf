variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "mantra-app"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "snowflake_account_name" {
  description = "Snowflake account name (part after organization-)"
  type        = string
  sensitive   = true
}

variable "snowflake_organization_name" {
  description = "Snowflake organization name"
  type        = string
  sensitive   = true
}

variable "snowflake_username" {
  description = "Snowflake username"
  type        = string
  sensitive   = true
}

variable "snowflake_password" {
  description = "Snowflake password"
  type        = string
  sensitive   = true
}

variable "snowflake_region" {
  description = "Snowflake region"
  type        = string
  default     = "us-west-2"
}

variable "snowflake_warehouse" {
  description = "Snowflake warehouse name"
  type        = string
  default     = "COMPUTE_WH"
}

variable "snowflake_database" {
  description = "Snowflake database name"
  type        = string
  default     = "MANTRA_DB"
}

variable "snowflake_schema" {
  description = "Snowflake schema name"
  type        = string
  default     = "PUBLIC"
}

variable "mantra_app_username" {
  description = "Username for the Mantra app Snowflake user"
  type        = string
  default     = "MANTRA_APP_USER"
}

variable "mantra_app_password" {
  description = "Password for the Mantra app Snowflake user"
  type        = string
  sensitive   = true
}

variable "snowflake_account_id" {
  description = "Snowflake AWS account ID for cross-account access"
  type        = string
  default     = "123456789012"  # This will be provided by Snowflake
}

variable "snowflake_external_id" {
  description = "External ID for Snowflake cross-account access"
  type        = string
  sensitive   = true
}