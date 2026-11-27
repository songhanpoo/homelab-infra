locals {
  # A YAML file that is entirely comments/blank lines is skipped (yamldecode would fail on it),
  # so its add-on is absent from local.config.
  files = fileset("${path.module}/envs", "**/*.yaml")
  docs  = [for f in local.files : file("${path.module}/envs/${f}")]
  config = merge([
    for raw in local.docs :
    yamldecode(raw) if length(regexall("(?m)^\\s*[^#\\s]", raw)) > 0
  ]...)

  # Empty map when airflow.yaml is commented out; helm_release.airflow for_each's over this.
  airflow = try({ airflow = local.config.airflow }, {})
}
