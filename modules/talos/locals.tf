locals {
  factory_url = "https://factory.talos.dev"

  platform   = var.image.platform
  arch       = var.image.arch
  version    = var.image.version
  image_type = var.image.image_type

  # Determine which schematics are configured.
  # If var.image.schematics is provided, use it. Otherwise, fall back to var.image.schematic.
  schematics = (
    var.image.schematics != null
    ? var.image.schematics
    : (var.image.schematic != null ? { "default" = var.image.schematic } : {})
  )

  schematic_ids = {
    for k, v in data.http.schematic_id : k => jsondecode(v.response_body)["id"]
  }

  # Map each node to its corresponding schematic key ("gpu", "normal", or "default")
  node_schematic_keys = {
    for k, v in var.nodes : k => (
      length(try(v.hostdevs, [])) > 0
      ? (contains(keys(local.schematics), "gpu") ? "gpu" : "default")
      : (contains(keys(local.schematics), "normal") ? "normal" : "default")
    )
  }

  schematic_id = lookup(local.schematic_ids, "default", lookup(local.schematic_ids, "normal", null))
  image_id     = local.schematic_id != null ? "${local.schematic_id}_${local.version}" : null
}
