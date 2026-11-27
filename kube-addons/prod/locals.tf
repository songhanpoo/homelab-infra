locals {
  # A YAML file that is entirely comments/blank lines is skipped (yamldecode would fail on it),
  # so its add-on is absent from local.config.
  files = fileset("${path.module}/envs", "**/*.yaml")
  docs  = [for f in local.files : file("${path.module}/envs/${f}")]
  config = merge([
    for raw in local.docs :
    yamldecode(raw) if length(regexall("(?m)^\\s*[^#\\s]", raw)) > 0
  ]...)
}
