# Snowflake Database
resource "snowflake_database" "mantra_db" {
  name    = var.snowflake_database
  comment = "Database for Mantra Recitation API"
}

# Snowflake Schema
resource "snowflake_schema" "mantra_schema" {
  database = snowflake_database.mantra_db.name
  name     = var.snowflake_schema
  comment  = "Schema for Mantra app tables"
}

# Custom Role for Mantra App
resource "snowflake_account_role" "mantra_app_role" {
  name    = "MANTRA_APP_ROLE"
  comment = "Role for Mantra Recitation API with required permissions"
}

# Application User
resource "snowflake_user" "mantra_app_user" {
  name         = var.mantra_app_username
  login_name   = var.mantra_app_username
  comment      = "Application user for Mantra Recitation API"
  password     = var.mantra_app_password
  disabled     = false
  
  default_warehouse = var.snowflake_warehouse
  default_role      = snowflake_account_role.mantra_app_role.name
  default_namespace = "${snowflake_database.mantra_db.name}.${snowflake_schema.mantra_schema.name}"

  must_change_password = false
}

# Grant role to user
resource "snowflake_grant_account_role" "mantra_app_user_grant" {
  role_name = snowflake_account_role.mantra_app_role.name
  user_name = snowflake_user.mantra_app_user.name
}

# Grant database usage to role
resource "snowflake_grant_privileges_to_account_role" "mantra_db_usage" {
  account_role_name = snowflake_account_role.mantra_app_role.name
  privileges        = ["USAGE"]
  
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.mantra_db.name
  }
}

# Grant schema usage to role
resource "snowflake_grant_privileges_to_account_role" "mantra_schema_usage" {
  account_role_name = snowflake_account_role.mantra_app_role.name
  privileges        = ["USAGE"]
  
  on_schema {
    schema_name = "\"${snowflake_database.mantra_db.name}\".\"${snowflake_schema.mantra_schema.name}\""
  }
}

# Grant table privileges to role
resource "snowflake_grant_privileges_to_account_role" "mantra_schema_create_table" {
  account_role_name = snowflake_account_role.mantra_app_role.name
  privileges        = ["CREATE TABLE"]
  
  on_schema {
    schema_name = "\"${snowflake_database.mantra_db.name}\".\"${snowflake_schema.mantra_schema.name}\""
  }
}

resource "snowflake_grant_privileges_to_account_role" "mantra_schema_create_view" {
  account_role_name = snowflake_account_role.mantra_app_role.name
  privileges        = ["CREATE VIEW"]
  
  on_schema {
    schema_name = "\"${snowflake_database.mantra_db.name}\".\"${snowflake_schema.mantra_schema.name}\""
  }
}

# Grant warehouse usage to role
resource "snowflake_grant_privileges_to_account_role" "mantra_warehouse_usage" {
  account_role_name = snowflake_account_role.mantra_app_role.name
  privileges        = ["USAGE", "OPERATE"]
  
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = var.snowflake_warehouse
  }
}

# Grant future table privileges (for tables created later)
resource "snowflake_grant_privileges_to_account_role" "future_tables" {
  account_role_name = snowflake_account_role.mantra_app_role.name
  privileges        = ["SELECT", "INSERT", "UPDATE", "DELETE"]
  
  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_schema          = "\"${snowflake_database.mantra_db.name}\".\"${snowflake_schema.mantra_schema.name}\""
    }
  }
}