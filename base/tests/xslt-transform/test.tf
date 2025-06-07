# ────────────────────────────────────────────────────────────
# 1) Create a quick-and-dirty pool so we have somewhere to put disks
# ────────────────────────────────────────────────────────────
resource "libvirt_pool" "test_pool" {
  name = "test-pool"
  type = "dir"

  target {
    # this directory almost always exists on a standard libvirt host
    path = "/var/lib/libvirt/images"
  }
}

# ────────────────────────────────────────────────────────────
# 2) A tiny 16 MiB QCOW2 volume
# ────────────────────────────────────────────────────────────
resource "libvirt_volume" "tiny" {
  name   = "tiny.qcow2"
  pool   = libvirt_pool.test_pool.name
  format = "qcow2"
  size   = 16 * 1024 * 1024   # 16 MiB
}

# ────────────────────────────────────────────────────────────
# 3) Minimal VM that applies your XSLT and does nothing else
# ────────────────────────────────────────────────────────────
resource "libvirt_domain" "test" {
  name   = "test-transform"
  memory = 64
  vcpu   = 1

  # attach the tiny disk
  disk {
    volume_id = libvirt_volume.tiny.id
  }

  # default libvirt network ‘default’ — adjust if yours is named differently
  network_interface {
    network_name   = "default"
    wait_for_lease = false
  }

  # no display, just a console
  graphics {
    type        = "spice"
    listen_type = "none"
  }
  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  # apply your transform
  xml {
    xslt = file("${path.module}/config/memory_backing.xslt")
  }

  autostart = false
}
