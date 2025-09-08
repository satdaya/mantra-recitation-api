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
resource "snowflake_role" "mantra_app_role" {
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
  default_role      = snowflake_role.mantra_app_role.name
  default_namespace = "${snowflake_database.mantra_db.name}.${snowflake_schema.mantra_schema.name}"

  must_change_password = false
}

# Grant role to user
resource "snowflake_role_grants" "mantra_app_user_grant" {
  role_name = snowflake_role.mantra_app_role.name
  users     = [snowflake_user.mantra_app_user.name]
}

# Grant database usage to role
resource "snowflake_database_grant" "mantra_db_usage" {
  database_name = snowflake_database.mantra_db.name
  privilege     = "USAGE"
  roles         = [snowflake_role.mantra_app_role.name]
}

# Grant schema usage to role
resource "snowflake_schema_grant" "mantra_schema_usage" {
  database_name = snowflake_database.mantra_db.name
  schema_name   = snowflake_schema.mantra_schema.name
  privilege     = "USAGE"
  roles         = [snowflake_role.mantra_app_role.name]
}

# Grant table privileges to role
resource "snowflake_schema_grant" "mantra_schema_create_table" {
  database_name = snowflake_database.mantra_db.name
  schema_name   = snowflake_schema.mantra_schema.name
  privilege     = "CREATE TABLE"
  roles         = [snowflake_role.mantra_app_role.name]
}

resource "snowflake_schema_grant" "mantra_schema_create_view" {
  database_name = snowflake_database.mantra_db.name
  schema_name   = snowflake_schema.mantra_schema.name
  privilege     = "CREATE VIEW"
  roles         = [snowflake_role.mantra_app_role.name]
}

# Grant warehouse usage to role
resource "snowflake_warehouse_grant" "mantra_warehouse_usage" {
  warehouse_name = var.snowflake_warehouse
  privilege      = "USAGE"
  roles          = [snowflake_role.mantra_app_role.name]
}

resource "snowflake_warehouse_grant" "mantra_warehouse_operate" {
  warehouse_name = var.snowflake_warehouse
  privilege      = "OPERATE"
  roles          = [snowflake_role.mantra_app_role.name]
}

# Grant future table privileges (for tables created later)
resource "snowflake_table_grant" "future_tables_select" {
  database_name = snowflake_database.mantra_db.name
  schema_name   = snowflake_schema.mantra_schema.name
  privilege     = "SELECT"
  roles         = [snowflake_role.mantra_app_role.name]
  on_future     = true
}

resource "snowflake_table_grant" "future_tables_insert" {
  database_name = snowflake_database.mantra_db.name
  schema_name   = snowflake_schema.mantra_schema.name
  privilege     = "INSERT"
  roles         = [snowflake_role.mantra_app_role.name]
  on_future     = true
}

resource "snowflake_table_grant" "future_tables_update" {
  database_name = snowflake_database.mantra_db.name
  schema_name   = snowflake_schema.mantra_schema.name
  privilege     = "UPDATE"
  roles         = [snowflake_role.mantra_app_role.name]
  on_future     = true
}

resource "snowflake_table_grant" "future_tables_delete" {
  database_name = snowflake_database.mantra_db.name
  schema_name   = snowflake_schema.mantra_schema.name
  privilege     = "DELETE"
  roles         = [snowflake_role.mantra_app_role.name]
  on_future     = true
}