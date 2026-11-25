resource "pihole_dns_record" "this" {
  for_each = var.records

  domain = each.key
  ip     = each.value
}
