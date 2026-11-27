# No production databases are managed yet. Add modules like this (see ../nonprod/main.tf):
#
#   module "example_db" {
#     source   = "../../modules/pg-bootstrap"
#     app_name = "example"
#   }
#
# Then add a provider "postgresql" block that reads its password from a sensitive variable,
# not from a value written in the file.
