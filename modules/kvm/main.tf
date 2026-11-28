resource "libvirt_volume" "base" {
  name = "${local.distribution}-${local.image_name}-base.img"
  pool = "default"

  create = {
    content = {
      url = "${local.factory_url}/${local.image_name}/current/${local.image_name}-server-cloudimg-${local.arch}.${local.image_type}"
    }
  }
}

# https://cloud-images.ubuntu.com/plucky/current/plucky-server-cloudimg-amd64.img
# https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64-disk-kvm.img"

resource "libvirt_volume" "vm_disk" {
  for_each = var.nodes
  name     = "${each.key}.qcow2"
  capacity = each.value.disk_size * 1024 * 1024
  pool     = each.value.datastore_id
  target   = { format = { type = "qcow2" } }
  backing_store = {
    path   = libvirt_volume.base.id
    target = { format = { type = "img" } }
  }
}

resource "libvirt_cloudinit_disk" "vm_init" {
  for_each = var.nodes
  name     = "${each.key}.iso"

  # User-data: Configure root password, enable SSH, install packages
  user_data = each.value.user_data

  # Meta-data: Instance identification
  meta_data = each.value.meta_data

  # Network config: Use DHCP (default behavior)
  network_config = each.value.network_config
}

resource "libvirt_volume" "vm_cloudinit" {
  for_each = var.nodes
  name     = "${each.key}.iso"
  pool     = "default"

  create = {
    content = {
      url = libvirt_cloudinit_disk.vm_init[each.key].path
    }
  }

  # "create" is only used when the volume is first uploaded. The ISO path is a temp file on the
  # machine running Terraform (infra/Makefile fixes TMPDIR so it matches everywhere), and the
  # provider cannot update a volume in place. So edited cloud-init data is NOT uploaded.
  # To push edited cloud-init data on purpose, replace the volume:
  #   terraform apply -replace='module.virtual-machine.libvirt_volume.vm_cloudinit["<node>"]'
  lifecycle {
    ignore_changes = [create]
  }
}

# Create libvirt domains for each node
resource "libvirt_domain" "node" {
  for_each  = var.nodes
  name      = each.key
  memory    = each.value.memory * 1024
  vcpu      = each.value.cpu
  type      = "kvm"
  autostart = true
  running   = true

  cpu = {
    mode = "host-passthrough"
  }

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
    boot_devices = [
      {
        dev = "cdrom"
      },
      {
        dev = "hd"
      }
    ]
  }

  devices = {
    # autostart = true
    disks = [
      {
        device = "cdrom"
        source = {
          file = {
            file = libvirt_volume.vm_cloudinit[each.key].path
          }
        }
        target = {
          dev = "sda"
          bus = "sata"
        }
      },
      {
        device = "disk"
        backing_store = {
          format = {
            type = "qcow2"
          }
          source = {
            file = {
              file = libvirt_volume.base.path
            }
          }
        }
        source = {
          file = {
            file = libvirt_volume.vm_disk[each.key].id
          }
        }
        driver = {
          name    = "qemu"
          type    = "qcow2"
          discard = "unmap"
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      },
    ]

    # Network interface on default network (DHCP)
    interfaces = [
      {
        model = {
          type = "virtio"
        }
        source = {
          bridge = {
            bridge = "br0"
          }
        }
      }
    ]

    hostdevs = (
      length(try(each.value.hostdevs, [])) > 0
      ? [
        for hostdev in each.value.hostdevs : {
          managed = true

          // Use subsys_pci for PCI passthrough with vfio driver
          subsys_pci = {
            // <driver name='vfio'/>
            driver = {
              name = "vfio"
            }

            // <source><address domain='0x0000' bus='0x06' slot='0x00' function='0x0'/></source>
            // Parse "0000:06:00.0" -> domain=0, bus=6, slot=0, function=0
            source = {
              address = {
                domain   = parseint(split(":", hostdev.address)[0], 16)
                bus      = parseint(split(":", hostdev.address)[1], 16)
                slot     = parseint(split(".", split(":", hostdev.address)[2])[0], 16)
                function = parseint(split(".", split(":", hostdev.address)[2])[1], 16)
              }
            }
          }

          // <alias name='hostdev0'/>
          alias = {
            name = try(hostdev.alias, "hostdev0")
          }
        }
      ]
      : null
    )

    # Graphics console (VNC)
    graphics = [{
      vnc = {
        listen_type = "address"
      }
    }]
  }
}
