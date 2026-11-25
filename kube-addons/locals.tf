locals {
  # envs/prod/** holds cluster-wide/singleton infra (kube-system, kube-monitoring, and the
  # non-namespaced platform pieces); envs/dev/** holds per-app workloads (kube-orchestrations).
  # Both are merged into one local.config, exactly as the old single envs/dev.yaml was -
  # this keeps one shared state file and one default `terraform apply` for the whole cluster.
  # See Makefile's PROD_TARGETS/DEV_TARGETS for scoped applies via `-target`.
  prod_files = fileset("${path.module}/envs/prod", "**/*.yaml")
  dev_files  = fileset("${path.module}/envs/dev", "**/*.yaml")

  # A YAML file that is entirely comments/blank lines is skipped (yamldecode would fail on it),
  # so its add-on is absent from local.config and its helm_release (count = 0) gets destroyed.
  prod_docs = [for f in local.prod_files : file("${path.module}/envs/prod/${f}")]
  dev_docs  = [for f in local.dev_files : file("${path.module}/envs/dev/${f}")]
  config = merge([
    for raw in concat(local.prod_docs, local.dev_docs) :
    yamldecode(raw) if length(regexall("(?m)^\\s*[^#\\s]", raw)) > 0
  ]...)

  # Empty map when jenkins.yaml is commented out; helm_release.jenkins for_each's over this.
  jenkins = try({ jenkins = local.config.jenkins }, {})

  # Empty map when airflow.yaml is commented out; helm_release.airflow for_each's over this.
  airflow = try({ airflow = local.config.airflow }, {})
}
