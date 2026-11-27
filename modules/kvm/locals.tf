locals {
  factory_url  = "https://cloud-images.ubuntu.com"
  arch         = var.image.arch
  distribution = var.image.distribution
  image_type   = var.image.image_type
  image_name   = var.image.image_name
}
