# ====================================================================
# 0. Core Infrastructure Database & Schema Creation
# ====================================================================
resource "postgresql_database" "app_db" {
  name              = "${var.app_name}_production_db"
  allow_connections = true
}

# Creates the custom schema ONLY if the toggle is true
resource "postgresql_schema" "app_schema" {
  count    = var.is_create_schema ? 1 : 0
  name     = "${var.app_name}_schema"
  database = postgresql_database.app_db.name
}

# LOCAL STATE: Dynamically tracks which schemas should receive permissions
locals {
  target_schemas = compact([
    "public",
    var.is_create_schema ? "${var.app_name}_schema" : ""
  ])
}

# ====================================================================
# 1. Admin CI/CD User Role & Permissions
# ====================================================================
resource "postgresql_role" "admin_cicd_user" {
  count           = var.is_create_admin ? 1 : 0
  name            = "${var.app_name}_admin_cicd_user"
  login           = true
  password        = var.admin_password
  create_database = true
  create_role     = true
}

resource "postgresql_grant" "admin_schema_grant" {
  # Loops through all schemas in our local list ("public" and optionally your custom schema)
  for_each    = var.is_create_admin ? toset(local.target_schemas) : []
  database    = postgresql_database.app_db.name
  schema      = each.value
  role        = postgresql_role.admin_cicd_user[0].name
  object_type = "schema"
  privileges  = ["ALL"]
}

# ====================================================================
# 2. Owner User Role & Permissions (Sequenced after Admin)
# ====================================================================
resource "postgresql_role" "owner_user" {
  count    = var.is_create_owner ? 1 : 0
  name     = "${var.app_name}_owner_user"
  login    = true
  password = var.owner_password
}

resource "postgresql_grant" "owner_schema_grant" {
  for_each    = var.is_create_owner ? toset(local.target_schemas) : []
  database    = postgresql_database.app_db.name
  schema      = each.value
  role        = postgresql_role.owner_user[0].name
  object_type = "schema"
  privileges  = ["USAGE", "CREATE"]

  depends_on = [postgresql_grant.admin_schema_grant]
}

# ====================================================================
# 3. Application User Role & Permissions (Sequenced after Owner)
# ====================================================================
resource "postgresql_role" "app_user" {
  count    = var.is_create_app ? 1 : 0
  name     = "${var.app_name}_app_user"
  login    = true
  password = var.app_password
}

resource "postgresql_grant" "app_schema_usage" {
  for_each    = var.is_create_app ? toset(local.target_schemas) : []
  database    = postgresql_database.app_db.name
  schema      = each.value
  role        = postgresql_role.app_user[0].name
  object_type = "schema"
  privileges  = ["USAGE"]

  depends_on = [postgresql_grant.owner_schema_grant]
}

resource "postgresql_default_privileges" "app_default_tables" {
  for_each    = var.is_create_app ? toset(local.target_schemas) : []
  database    = postgresql_database.app_db.name
  schema      = each.value
  role        = postgresql_role.app_user[0].name
  owner       = var.is_create_owner ? postgresql_role.owner_user[0].name : "postgres"
  object_type = "table"
  privileges  = ["SELECT", "INSERT", "UPDATE", "DELETE"]
  depends_on  = [postgresql_grant.app_schema_usage]
}

resource "postgresql_default_privileges" "app_default_sequences" {
  for_each    = var.is_create_app ? toset(local.target_schemas) : []
  database    = postgresql_database.app_db.name
  schema      = each.value
  role        = postgresql_role.app_user[0].name
  owner       = var.is_create_owner ? postgresql_role.owner_user[0].name : "postgres"
  object_type = "sequence"
  privileges  = ["USAGE", "SELECT"]
  depends_on  = [postgresql_grant.app_schema_usage]
}

resource "postgresql_default_privileges" "app_default_functions" {
  for_each    = var.is_create_app ? toset(local.target_schemas) : []
  database    = postgresql_database.app_db.name
  schema      = each.value
  role        = postgresql_role.app_user[0].name
  owner       = var.is_create_owner ? postgresql_role.owner_user[0].name : "postgres"
  object_type = "function"
  privileges  = ["EXECUTE"]
  depends_on  = [postgresql_grant.app_schema_usage]
}

# ====================================================================
# 4. Read Only User Role & Permissions (Sequenced after App)
# ====================================================================
resource "postgresql_role" "read_only_user" {
  count    = var.is_create_readonly ? 1 : 0
  name     = "${var.app_name}_read_only"
  login    = true
  password = var.readonly_password
}

resource "postgresql_grant" "readonly_schema_usage" {
  for_each    = var.is_create_readonly ? toset(local.target_schemas) : []
  database    = postgresql_database.app_db.name
  schema      = each.value
  role        = postgresql_role.read_only_user[0].name
  object_type = "schema"
  privileges  = ["USAGE"]

  depends_on = [postgresql_default_privileges.app_default_functions]
}

resource "postgresql_default_privileges" "readonly_default_tables" {
  for_each    = var.is_create_readonly ? toset(local.target_schemas) : []
  database    = postgresql_database.app_db.name
  schema      = each.value
  role        = postgresql_role.read_only_user[0].name
  owner       = var.is_create_owner ? postgresql_role.owner_user[0].name : "postgres"
  object_type = "table"
  privileges  = ["SELECT"]
  depends_on  = [postgresql_grant.readonly_schema_usage]
}

# ====================================================================
# 5. Support User Role & Permissions (Sequenced after Read Only)
# ====================================================================
resource "postgresql_role" "support_user" {
  count    = var.is_create_support ? 1 : 0
  name     = "${var.app_name}_support"
  login    = true
  password = var.support_password
}

resource "postgresql_grant" "support_schema_usage" {
  for_each    = var.is_create_support ? toset(local.target_schemas) : []
  database    = postgresql_database.app_db.name
  schema      = each.value
  role        = postgresql_role.support_user[0].name
  object_type = "schema"
  privileges  = ["USAGE"]

  depends_on = [postgresql_default_privileges.readonly_default_tables]
}

resource "postgresql_default_privileges" "support_default_tables" {
  for_each    = var.is_create_support ? toset(local.target_schemas) : []
  database    = postgresql_database.app_db.name
  schema      = each.value
  role        = postgresql_role.support_user[0].name
  owner       = var.is_create_owner ? postgresql_role.owner_user[0].name : "postgres"
  object_type = "table"
  privileges  = ["SELECT"]
  depends_on  = [postgresql_grant.support_schema_usage]
}

resource "postgresql_default_privileges" "support_default_functions" {
  for_each    = var.is_create_support ? toset(local.target_schemas) : []
  database    = postgresql_database.app_db.name
  schema      = each.value
  role        = postgresql_role.support_user[0].name
  owner       = var.is_create_owner ? postgresql_role.owner_user[0].name : "postgres"
  object_type = "function"
  privileges  = ["EXECUTE"]
  depends_on  = [postgresql_grant.support_schema_usage]
}
