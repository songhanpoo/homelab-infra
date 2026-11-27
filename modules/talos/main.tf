# Terraform configuration for KVM-based Talos cluster deployment
data "http" "schematic_id" {
  for_each     = local.schematics
  url          = "${local.factory_url}/schematics"
  method       = "POST"
  request_body = each.value
}

# Create a libvirt network with NAT forwarding and DHCP
# resource "libvirt_network" "virbr1" {
#   name = var.additional_networks.name
#   forward = {
#     mode = var.additional_networks.mode
#   }
#   autostart = var.additional_networks.auto_start

#   dns = {
#     enabled = true
#     forwarders = [
#       {
#         domain = "."
#         addr   = "1.1.1.1"
#       },
#       {
#         domain = "."
#         addr   = "1.0.0.1"
#       }
#     ]
#   }

#   ips = [
#     {
#       address = var.additional_networks.cidr
#       prefix  = var.additional_networks.prefix
#       dhcp = {
#         enabled = var.additional_networks.dhcp_enabled
#         ranges = [
#           {
#             start = var.additional_networks.dhcp_start
#             end   = var.additional_networks.dhcp_end
#           }
#         ]

#         hosts = [
#           for node in var.nodes : {
#             ip  = node.ip
#             mac = node.mac_address
#           }
#         ]
#       }
#     }
#   ]
# }

# Create NFS pools if specified
# resource "libvirt_pool" "pools" {
#   for_each = { for p in var.nfs_pools : p.name => p }

#   name = each.value.name
#   type = "netfs"

#   target = {
#     path = each.value.host_path
#   }

#   source = {
#     host = [
#       {
#         name = each.value.host
#         port = try(each.value.port, null)
#       }
#     ]
#     dir = {
#       path = each.value.target_path
#     }
#   }
# }

# Create boot image volume
resource "libvirt_volume" "boot_image" {
  for_each = local.schematics
  name     = "talos-${local.version}-${local.platform}-${local.arch}-${each.key}.${local.image_type}"
  pool     = "default"

  create = {
    content = {
      url = "${local.factory_url}/image/${local.schematic_ids[each.key]}/${local.version}/${local.platform}-${local.arch}.${local.image_type}"
    }
  }

  # lifecycle {
  #   prevent_destroy = true
  # }
}

# # Create libvirt volumes for each node
resource "libvirt_volume" "node" {
  for_each = var.nodes
  name     = "${each.key}.qcow2"
  capacity = each.value.disk_size * 1024 * 1024
  pool     = each.value.datastore_id
}

# Create libvirt domains for each node
resource "libvirt_domain" "nodes" {
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

  features = {
    acpi = true
  }

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
    boot_devices = [
      {
        dev = "hd"
      },
      {
        dev = "cdrom"
      }
    ]
    # --- Conditional UEFI configuration ---
    # Only applies to nodes that have hostdevs defined (e.g., talos-work-4)
    loader          = "/usr/share/OVMF/OVMF_CODE_4M.fd"
    loader_readonly = "yes"
    loader_type     = "pflash"
    #
    nv_ram = {
      # Dynamically names the NVRAM file per-VM (e.g., "talos-work-4-vars.fd") so they don't overwrite each other
      nv_ram   = "/var/lib/libvirt/qemu/nvram/${each.key}-vars.fd"
      template = "/usr/share/OVMF/OVMF_VARS_4M.fd"
    }
  }

  devices = {
    autostart = true
    disks = [
      {
        source = {
          file = {
            file = libvirt_volume.node[each.key].id
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      },
      {
        device = "cdrom"
        source = {
          file = {
            file = libvirt_volume.boot_image[local.node_schematic_keys[each.key]].id
          }
        }
        target = {
          dev = "sda"
          bus = "sata"
        }
      }
    ]

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
        mac = {
          address = each.value.mac_address
        }
      }
    ]

    graphics = [{
      vnc = {
        listen_type = "address"
      }
    }]

    // Render PCI host devices from each.value.hostdevs, e.g., { address = "0000:06:00.0" }
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
                domain   = parseint(split(":", hostdev.address)[0], 16) == 0 ? null : parseint(split(":", hostdev.address)[0], 16)
                bus      = parseint(split(":", hostdev.address)[1], 16) == 0 ? null : parseint(split(":", hostdev.address)[1], 16)
                slot     = parseint(split(".", split(":", hostdev.address)[2])[0], 16) == 0 ? null : parseint(split(".", split(":", hostdev.address)[2])[0], 16)
                function = parseint(split(".", split(":", hostdev.address)[2])[1], 16) == 0 ? null : parseint(split(".", split(":", hostdev.address)[2])[1], 16)
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

    channels = [
      {
        source = {
          unix = {
            mode = "bind"
          }
        }

        target = {
          virt_io = {
            name = "org.qemu.guest_agent.0"
          }
        }
      }
    ]

    consoles = [{
      target_type = "serial"
      target_port = "0"
    }]
  }

  metadata = length(try(each.value.hostdevs, [])) > 0 ? {
    xml = <<EOF
    <xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
      <xsl:template match="@*|node()">
        <xsl:copy>
          <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
      </xsl:template>
      <xsl:template match="domain">
        <xsl:copy>
          <xsl:apply-templates select="@*|node()"/>
          <memtune>
            <hard_limit unit="KiB">16777216</hard_limit> <!-- 20 GiB Hard Cap on Host Allocation -->
          </memtune>
        </xsl:copy>
      </xsl:template>
    </xsl:stylesheet>
    EOF
  } : null

  lifecycle {
    ignore_changes = [
      devices.hostdevs,
      devices.disks
    ]
  }
}

resource "talos_machine_secrets" "this" {
  talos_version = var.cluster.talos_version
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster.name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = [for k, v in var.nodes : v.ip]
  endpoints            = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"]
}

data "talos_machine_configuration" "this" {
  for_each         = var.nodes
  cluster_name     = var.cluster.name
  cluster_endpoint = "https://${var.cluster.endpoint}:6443"
  talos_version    = var.cluster.talos_version
  machine_type     = each.value.machine_type
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

resource "talos_machine_configuration_apply" "this" {
  for_each                    = var.nodes
  node                        = each.value.ip
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration

  config_patches = concat(
    [
      yamlencode({
        machine = {
          install = {
            disk  = "/dev/vda"
            image = "factory.talos.dev/${local.platform}-installer/${local.schematic_ids[local.node_schematic_keys[each.key]]}:${local.version}"
          }
          network = {
            hostname = "${each.key}.talos.local"
            nameservers = [
              "192.168.1.79",
            ]
          }
          registries = {
            config = {
              "nexus-docker.local.proxy" = {
                tls = {
                  insecureSkipVerify = true
                }
              }
              "nexus-docker-private.local.proxy" = {
                tls = {
                  insecureSkipVerify = true
                }
              }
              "192.168.1.17:5000" = {
                tls = {
                  insecureSkipVerify = true
                }
              }
            }
          }
        }
      })
    ],
    length(try(each.value.hostdevs, [])) > 0 ? [
      yamlencode({
        machine = {
          kernel = {
            modules = [
              {
                name = "amdgpu"
              }
            ]
          }
          install = {
            extraKernelArgs = [
              # "iommu=pt",
              # "vfio-pci.ids=1002:66a1",
              # "rd.driver.blacklist=amdgpu",
              # "modprobe.blacklist=amdgpu",
              # "ttm.pages_limit=41904",
              # "amdgpu.gttsize=16384",
              "initcall_blacklist=sysfb_init"
            ]
          }
        }
      })
    ] : []
  )

  depends_on = [libvirt_domain.nodes]
}

resource "talos_machine_bootstrap" "this" {
  node                 = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"][0]
  endpoint             = var.cluster.endpoint
  client_configuration = talos_machine_secrets.this.client_configuration
  depends_on           = [libvirt_domain.nodes]
}

data "talos_cluster_health" "this" {
  depends_on = [
    talos_machine_configuration_apply.this,
    talos_machine_bootstrap.this,
    libvirt_domain.nodes
  ]
  client_configuration   = data.talos_client_configuration.this.client_configuration
  control_plane_nodes    = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"]
  worker_nodes           = [for k, v in var.nodes : v.ip if v.machine_type == "worker"]
  endpoints              = data.talos_client_configuration.this.endpoints
  skip_kubernetes_checks = true
  timeouts = {
    read = "10m"
  }
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = var.cluster.endpoint
  node                 = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"][0]
  depends_on           = [data.talos_cluster_health.this]
}

resource "local_file" "kubeconfig" {
  content              = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename             = "${pathexpand("~")}/.kube/${var.cluster.name}/kubeconfig"
  directory_permission = "0755"
  file_permission      = "0600"

  depends_on = [talos_cluster_kubeconfig.this]
}

resource "local_file" "talosconfig" {
  content              = data.talos_client_configuration.this.talos_config
  filename             = "${pathexpand("~")}/.talos/${var.cluster.name}/talosconfig"
  directory_permission = "0755"
  file_permission      = "0600"

  depends_on = [data.talos_client_configuration.this]
}
