# Jenkins and the parked Airflow secrets are no longer managed here. These blocks drop them
# from state WITHOUT deleting anything. To delete them, remove them from the cluster by hand.

removed {
  from = helm_release.jenkins
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubernetes_secret_v1.airflow_jwt_secret
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubernetes_secret_v1.airflow_postgresql_secret
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubernetes_secret_v1.airflow_webserver_secret
  lifecycle {
    destroy = false
  }
}

removed {
  from = random_password.airflow_jwt_secret
  lifecycle {
    destroy = false
  }
}

removed {
  from = random_password.airflow_postgresql_secret
  lifecycle {
    destroy = false
  }
}

removed {
  from = random_password.airflow_webserver_secret
  lifecycle {
    destroy = false
  }
}
