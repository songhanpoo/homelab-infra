module "airflow_db" {
  source   = "../../modules/pg-bootstrap"
  app_name = "airflow"

  is_create_schema = false

  # Individual User Toggles
  is_create_admin = true
  is_create_owner = true
  is_create_app   = false
  # is_create_readonly = false  # <--- Setting this to false skips creating the read_only role
  # is_create_support  = false

  # Passwords
  admin_password    = "AdminP@ss18_!"
  owner_password    = "OwnerP@ss18_!"
  app_password      = "AppRunnerP@ss18_!"
  readonly_password = "AnalyticsP@ss18_!"
  support_password  = "OpsSupportP@ss18_!"
}

module "visa_bulletin_db" {
  source   = "../../modules/pg-bootstrap"
  app_name = "visa_bulletin"

  is_create_schema = true

  # Individual User Toggles
  is_create_admin = true
  is_create_owner = true
  is_create_app   = true
  # is_create_readonly = false  # <--- Setting this to false skips creating the read_only role
  # is_create_support  = false

  # Passwords
  admin_password    = "AdminP@ss18_!"
  owner_password    = "OwnerP@ss18_!"
  app_password      = "AppRunnerP@ss18_!"
  readonly_password = "AnalyticsP@ss18_!"
  support_password  = "OpsSupportP@ss18_!"
}

module "kestra_db" {
  source   = "../../modules/pg-bootstrap"
  app_name = "kestra"

  is_create_schema = true

  # Individual User Toggles
  is_create_admin = true
  is_create_owner = true
  is_create_app   = true
  # is_create_readonly = false  # <--- Setting this to false skips creating the read_only role
  # is_create_support  = false

  # Passwords
  admin_password    = "AdminP@ss18_!"
  owner_password    = "OwnerP@ss18_!"
  app_password      = "AppRunnerP@ss18_!"
  readonly_password = "AnalyticsP@ss18_!"
  support_password  = "OpsSupportP@ss18_!"
}
