variable "app_name" {
  type        = string
  description = "Application prefix name used to label resources and schemas"
}

# ====================================================================
# [NEW] Schema Creation Toggle
# ====================================================================
variable "is_create_schema" {
  type        = bool
  default     = true
  description = "If true, creates and manages a dedicated schema named '<ann_name_schema>'. If false, maps all permissions to the standard 'public' schema instead."
}

# ====================================================================
# User Creation Flags (Toggles)
# ====================================================================
variable "is_create_admin" {
  type        = bool
  default     = true
  description = "Whether to provision the Admin CI/CD user role"
}

variable "is_create_owner" {
  type        = bool
  default     = true
  description = "Whether to provision the primary schema Owner user role"
}

variable "is_create_app" {
  type        = bool
  default     = true
  description = "Whether to provision the active runtime Application user role"
}

variable "is_create_readonly" {
  type        = bool
  default     = true
  description = "Whether to provision the Analytics/Read-only user role"
}

variable "is_create_support" {
  type        = bool
  default     = true
  description = "Whether to provision the operational Support user role"
}

# ====================================================================
# Passwords (Sensitive Entries)
# ====================================================================
variable "admin_password" {
  type      = string
  sensitive = true
}

variable "owner_password" {
  type      = string
  sensitive = true
}

variable "app_password" {
  type      = string
  sensitive = true
}

variable "readonly_password" {
  type      = string
  sensitive = true
}

variable "support_password" {
  type      = string
  sensitive = true
}
