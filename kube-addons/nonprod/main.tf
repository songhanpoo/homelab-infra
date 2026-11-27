resource "helm_release" "nexus" {
  name            = local.config.nexus.name
  repository      = local.config.nexus.repository
  chart           = local.config.nexus.chart
  version         = local.config.nexus.version
  namespace       = local.config.nexus.namespace
  upgrade_install = true
  wait            = false
  values = [
    yamlencode(local.config.nexus.values_yaml)
  ]
}

resource "helm_release" "harness_delegate" {
  name            = local.config.harness_delegate.name
  repository      = local.config.harness_delegate.repository
  chart           = local.config.harness_delegate.chart
  version         = local.config.harness_delegate.version
  namespace       = local.config.harness_delegate.namespace
  upgrade_install = true
  wait            = false
  values = [
    yamlencode(local.config.harness_delegate.values_yaml)
  ]
}

resource "kubernetes_namespace_v1" "harness-executions" {
  metadata {
    name = "harness-executions"
  }
}

# resource "kubernetes_persistent_volume_claim_v1" "harness_executions_nfs" {
#   metadata {
#     name      = "harness-delegate-share-volume"
#     namespace = kubernetes_namespace_v1.harness-executions.metadata[0].name
#   }
#   spec {
#     access_modes       = ["ReadWriteMany"]
#     storage_class_name = "nfs-csi-builds"
#     resources {
#       requests = {
#         storage = "50Gi"
#       }
#     }
#   }
# }

resource "kubernetes_secret" "nexus-secret" {
  metadata {
    name      = "nexus-secret"
    namespace = "kube-orchestrations"
  }
  data = {
    "nexus-root-password" = "admin"
  }
}

resource "kubernetes_secret" "nexus-docker-registries" {
  metadata {
    name      = "nexus-docker-registries"
    namespace = "kube-orchestrations"
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "nexus-docker.local.proxy" = {
          "username" = "admin"
          "password" = kubernetes_secret.nexus-secret.data["nexus-root-password"]
          "auth"     = base64encode("admin:${kubernetes_secret.nexus-secret.data["nexus-root-password"]}")
        }
        "nexus-docker-private.local.proxy" = {
          "username" = "admin"
          "password" = kubernetes_secret.nexus-secret.data["nexus-root-password"]
          "auth"     = base64encode("admin:${kubernetes_secret.nexus-secret.data["nexus-root-password"]}")
        }
      }
    })
  }
}

resource "kubernetes_namespace_v1" "kube-orchestrations" {
  metadata {
    name = "kube-orchestrations"
  }
}

resource "kubernetes_namespace_v1" "kestra-executions" {
  metadata {
    name = "kestra-executions"
  }
}

# Secrets are namespaced: task pods in kestra-executions need their own copies.
resource "kubernetes_secret" "nexus_docker_registries_kestra" {
  metadata {
    name      = "nexus-docker-registries"
    namespace = kubernetes_namespace_v1.kestra-executions.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"
  data = kubernetes_secret.nexus-docker-registries.data
}

resource "kubernetes_secret_v1" "visa_bulletin_dag_credentials_kestra" {
  metadata {
    name      = "visa-bulletin-dag"
    namespace = kubernetes_namespace_v1.kestra-executions.metadata[0].name
  }

  data = kubernetes_secret_v1.visa_bulletin_dag_credentials.data
}

resource "kubernetes_secret_v1" "visa_bulletin_dag_credentials" {
  metadata {
    name      = "visa-bulletin-dag"
    namespace = "kube-orchestrations"
  }

  data = {
    DATABASE_URL         = "postgresql://visa_bulletin_app_user:AppRunnerP@ss18_!@192.168.1.120:5432/visa_bulletin_production_db"
    R2_ACCOUNT_ID        = "fe004ca1bb68c121a95abde4923caa66"
    R2_BUCKET_NAME       = "next-bulletin"
    R2_ACCESS_KEY_ID     = "c605e377719fde92217babea85b1375b"
    R2_SECRET_ACCESS_KEY = "13ddfd95f77f72996d2b080ff4c2ac50b158993ed4e2694cc938469fda03e488"
  }
}


resource "helm_release" "flaresolver" {
  name            = local.config.flaresolver.name
  namespace       = local.config.flaresolver.namespace
  repository      = local.config.flaresolver.repository
  chart           = local.config.flaresolver.chart
  version         = local.config.flaresolver.version
  wait            = false
  upgrade_install = true
  values = [
    yamlencode(local.config.flaresolver.values_yaml)
  ]
}

# Outline is a knowledge base and wiki system built on Node.js.
# resource "helm_release" "outline" {
#   name            = local.config.outline.name
#   namespace       = local.config.outline.namespace
#   repository      = local.config.outline.repository
#   chart           = local.config.outline.chart
#   wait            = false
#   upgrade_install = true
#   timeout         = 600
#   values = [
#     yamlencode(local.config.outline.values_yaml)
#   ]
# }

# Airflow – workflow orchestration
resource "helm_release" "airflow" {
  # envs/dev/kube-orchestrations/airflow.yaml fully commented out => no "airflow" key => destroyed.
  for_each        = local.airflow
  name            = each.value.name
  namespace       = each.value.namespace
  repository      = try(each.value.repository, null)
  chart           = each.value.chart
  version         = each.value.version
  wait            = false
  upgrade_install = false
  timeout         = 600
  values = [
    yamlencode(each.value.values_yaml)
  ]
}

# resource "random_password" "airflow_webserver_secret" {
#   length  = 32
#   special = true
# }
#
# resource "kubernetes_secret_v1" "airflow_webserver_secret" {
#   metadata {
#     name      = "airflow-webserver-secret"
#     namespace = "kube-orchestrations"
#   }
#
#   data = {
#     "webserver-secret-key" = base64encode(random_password.airflow_webserver_secret.result)
#   }
# }
#
# resource "random_password" "airflow_jwt_secret" {
#   length  = 32
#   special = true
# }
#
# resource "kubernetes_secret_v1" "airflow_jwt_secret" {
#   metadata {
#     name      = "airflow-jwt-secret-tf"
#     namespace = "kube-orchestrations"
#   }
#
#   data = {
#     "jwt-secret" = base64encode(random_password.airflow_jwt_secret.result)
#   }
# }
#
# resource "random_password" "airflow_postgresql_secret" {
#   length  = 24
#   special = true
# }
#
# resource "kubernetes_secret_v1" "airflow_postgresql_secret" {
#   metadata {
#     name      = "airflow-postgresql-secret"
#     namespace = "kube-orchestrations"
#   }
#
#   data = {
#     "postgres-password" = base64encode(random_password.airflow_postgresql_secret.result)
#   }
# }

# "jenkins-credentials" already exists in the cluster and its values are kept out of this repo.
# Terraform only reads it. The removed block drops the old resource from state WITHOUT deleting it.
# On a new cluster, create this secret (GITHUB_TOKEN, GITHUB_PRIVATE_KEY) before planning.
removed {
  from = kubernetes_secret_v1.jenkins_credentials
  lifecycle {
    destroy = false
  }
}

data "kubernetes_secret_v1" "jenkins_credentials" {
  metadata {
    name      = "jenkins-credentials"
    namespace = "kube-orchestrations"
  }
}

resource "kubernetes_secret_v1" "git_credentials" {
  metadata {
    name      = "git-credentials"
    namespace = "kube-orchestrations"
  }

  data = {
    "GIT_SYNC_USERNAME" = "songhanpoo"
    "GIT_SYNC_PASSWORD" = data.kubernetes_secret_v1.jenkins_credentials.data["GITHUB_TOKEN"]
    "GITSYNC_USERNAME"  = "songhanpoo"
    "GITSYNC_PASSWORD"  = data.kubernetes_secret_v1.jenkins_credentials.data["GITHUB_TOKEN"]
  }
}

resource "kubernetes_secret_v1" "git_ssh_key" {
  metadata {
    name      = "git-ssh-key"
    namespace = "kube-orchestrations"
  }

  data = {
    "gitSshKey" = data.kubernetes_secret_v1.jenkins_credentials.data["GITHUB_PRIVATE_KEY"]
  }
}

# resource "helm_release" "thinkread" {
#   name            = local.config.thinkread.name
#   namespace       = local.config.thinkread.namespace
#   chart           = local.config.thinkread.chart
#   wait            = false
#   upgrade_install = false

#   set = [for k, v in local.config.thinkread.values : { name = k, value = tostring(v) }]
# }

# crawl4ai – workflow orchestration
resource "helm_release" "crawl4ai" {
  name            = local.config.crawl4ai.name
  namespace       = local.config.crawl4ai.namespace
  repository      = try(local.config.crawl4ai.repository, null)
  chart           = local.config.crawl4ai.chart
  version         = local.config.crawl4ai.version
  wait            = false
  upgrade_install = true
  timeout         = 600
  values = [
    yamlencode(local.config.crawl4ai.values_yaml)
  ]
}

resource "helm_release" "kestra" {
  name            = local.config.kestra.name
  namespace       = local.config.kestra.namespace
  repository      = local.config.kestra.repository
  chart           = local.config.kestra.chart
  version         = local.config.kestra.version
  wait            = false
  upgrade_install = true
  values = [
    yamlencode(local.config.kestra.values_yaml)
  ]

  depends_on = [module.kestra_db]
}

# resource "helm_release" "supabase" {
#   name = "supabase"

#   repository = "https://supabase-community.github.io/supabase-kubernetes"
#   chart      = "supabase"
#   namespace  = "kube-orchestrations"
#   wait       = false
#   set = [
#     {
#       name  = "kong.ingress.className"
#       value = "nginx-internal"
#     },
#     {
#       name  = "kong.ingress.hosts[0].host"
#       value = "supabase.localdev.me"
#     },
#     {
#       name  = "kong.ingress.hosts[0].paths[0].path"
#       value = "/"
#     },
#     {
#       name  = "kong.ingress.hosts[0].paths[0].pathType"
#       value = "Prefix"
#     },
#     {
#       name  = "storage.persistence.enabled"
#       value = "true"
#     },
#     {
#       name  = "storage.persistence.storageClassName"
#       value = "nfs-csi"
#     },
#     {
#       name  = "db.persistence.enabled"
#       value = "true"
#     },
#     {
#       name  = "db.persistence.storageClassName"
#       value = "nfs-csi"
#     },
#     {
#       name  = "imgproxy.persistence.enabled"
#       value = "true"
#     },
#     {
#       name  = "imgproxy.persistence.storageClassName"
#       value = "nfs-csi"
#     }
#   ]
# }

# n8n is a powerful workflow automation tool that allows users to create and automate complex workflows using a visual interface. It supports a wide range of integrations with various services and applications, making it a versatile solution for automating tasks and processes across different platforms.
# resource "helm_release" "n8n" {
#   name       = local.config.n8n.name
#   repository = local.config.n8n.repository
#   chart      = local.config.n8n.chart
#   namespace  = local.config.n8n.namespace
#   wait       = false

#   values = [
#     yamlencode(local.config.n8n.values_yaml)
#   ]
# }

# resource "helm_release" "drone" {
#   name       = "drone"
#   repository = "https://community-charts.github.io/helm-charts"
#   chart      = "drone"
#   namespace  = "kube-orchestrations"
#
#   wait    = false
#   timeout = 600
#
#   set = [
#
#     # Environment variables
#     {
#       name  = "server.env.DRONE_SERVER_HOST"
#       value = "drone.localdev.me"
#     },
#     {
#       name  = "server.env.DRONE_SERVER_PROTO"
#       value = "http"
#     },
#     {
#       name  = "server.env.DRONE_SERVER_PROTO"
#       value = "http"
#     },
#     {
#       name  = "server.env.DRONE_DATABASE_DRIVER"
#       value = "postgres"
#     },
#
#     # Ingress
#     {
#       name  = "server.ingress.enabled"
#       value = "true"
#     },
#     {
#       name  = "server.ingress.hosts[0].host"
#       value = "drone.localdev.me"
#     },
#     {
#       name  = "server.ingress.className"
#       value = "nginx-internal"
#     },
#     {
#       name  = "server.ingress.hosts[0].paths[0].path"
#       value = "/"
#     },
#     {
#       name  = "server.ingress.hosts[0].paths[0].pathType"
#       value = "ImplementationSpecific"
#     },
#
#     {
#       name  = "server.secrets.DRONE_DATABASE_DATASOURCE"
#       value = "postgres://postgres:kicker-dane-cawing-flipper@192.168.1.120:5432/drone?sslmode=disable"
#     },
#     # {
#     #   name  = "server.secrets.DRONE_USER_CREATE"
#     #   value = "username:testuser,admin:true"
#     # },
#     # {
#     #   name  = "server.secrets.DRONE_USER_FILTER"
#     #   value = "testuser"
#     # },
#
#     {
#       name  = "server.persistentVolume.enabled"
#       value = "true"
#     },
#     {
#       name  = "server.persistentVolume.size"
#       value = "8Gi"
#     },
#     {
#       name  = "server.persistentVolume.storageClass"
#       value = "nfs-csi"
#     },
#   ]
# }

# resource "nginxproxymanager_proxy_host" "ingress-internal-http" {
#   domain_names            = ["*.localdev.me"]
#   forward_scheme          = "http"
#   forward_host            = "192.168.1.130"
#   forward_port            = 31674
#   caching_enabled         = true
#   allow_websocket_upgrade = false
#   block_exploits          = true
#   ssl_forced              = false
#   hsts_enabled            = false
#   hsts_subdomains         = false
#   http2_support           = true
# }

# resource "nginxproxymanager_proxy_host" "ingress-internal-https" {
#   domain_names            = ["*.localdev.me"]
#   forward_scheme          = "https"
#   forward_host            = "192.168.1.130"
#   forward_port            = 31594
#   caching_enabled         = true
#   allow_websocket_upgrade = false
#   block_exploits          = true
#   ssl_forced              = true
#   hsts_enabled            = false
#   hsts_subdomains         = false
#   http2_support           = true
# }

# resource "helm_release" "vault" {
#   name            = "vault"
#   repository      = "https://helm.releases.hashicorp.com"
#   chart           = "vault"
#   namespace       = "kube-system"
#   version         = "0.31.0"
#   wait            = true
#   upgrade_install = true

#   set = [
#     # Enable standalone mode
#     {
#       name  = "server.standalone.enabled"
#       value = "true"
#     },
#     # Enable UI
#     {
#       name  = "ui.enabled"
#       value = "true"
#     },

#     # Persistent storage
#     {
#       name  = "server.dataStorage.enabled"
#       value = "true"
#     },
#     {
#       name  = "server.dataStorage.size"
#       value = "10Gi"
#     },
#     {
#       name  = "server.dataStorage.enabled"
#       value = "true"
#     },
#     {
#       name  = "server.dataStorage.storageClass"
#       value = "nfs-csi"
#     },
#     {
#       name  = "server.dataStorage.accessMode"
#       value = "ReadWriteOnce"
#     },

#     # Ingress
#     {
#       name  = "server.ingress.enabled"
#       value = "true"
#     },
#     {
#       name  = "server.ingress.ingressClassName"
#       value = "nginx-internal"
#     },
#     {
#       name  = "server.ingress.hosts[0].host"
#       value = "vault.localdev.me"
#     },
#     {
#       name  = "server.ingress.hosts[0].paths[0]"
#       value = "/"
#     },

#     # Service (ClusterIP is correct behind ingress)
#     {
#       name  = "server.service.type"
#       value = "ClusterIP"
#     }
#   ]
# }

# resource "helm_release" "harness" {
#   name            = "harness"
#   namespace       = "kube-orchestrations"
#   chart           = "./charts/harness"
#   wait            = false
#   upgrade_install = true
# }

# resource "helm_release" "stump" {
#   name            = local.config.stump.name
#   namespace       = local.config.stump.namespace
#   chart           = local.config.stump.chart
#   wait            = false
#   upgrade_install = true
#   values = [
#     yamlencode(local.config.stump.values_yaml)
#   ]
# }

# floci moved off Kubernetes to a plain Docker container on 192.168.1.98 - see
# module.floci below. Talos nodes have no Docker socket, which the chart's
# "full" mode (needed for Lambda/RDS/ElastiCache/etc.) requires.
# module "floci" {
#   source = "../../modules/floci"
# }

resource "helm_release" "cloudflared" {
  name            = local.config.cloudflared.name
  repository      = local.config.cloudflared.repository
  chart           = local.config.cloudflared.chart
  version         = lookup(local.config.cloudflared, "version", null)
  namespace       = local.config.cloudflared.namespace
  wait            = false
  upgrade_install = true

  values = [
    yamlencode(local.config.cloudflared.values_yaml)
  ]
}

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
