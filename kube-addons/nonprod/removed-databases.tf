# The databases moved to databases/nonprod. These blocks make this root forget them
# WITHOUT deleting anything. Safe to delete this file once this root's state no longer
# lists module.*_db (also drop postgresql from required_providers then).

removed {
  from = module.airflow_db
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.visa_bulletin_db
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.kestra_db
  lifecycle {
    destroy = false
  }
}
