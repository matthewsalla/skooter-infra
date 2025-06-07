# terraform.tfvars (DO NOT COMMIT THIS FILE)
libvirt_user = "ubuntu"

host_ip = "192.168.1.222"
gateway_ip = "192.168.1.88"
k3s_public_domain = "k3s.example.com"

k3s_cluster_main_pool = "/mnt/BAY01_10TB/main_pool"
k3s_cluster_main_pool_name = "k3s_main_pool"

k3s_cluster_base_pool = "/var/lib/libvirt/base-images"
k3s_cluster_base_pool_name = "base-pool"

# This key gives you SSH access to VMs
ssh_key = "~/.ssh/id_rsa.pub"

k3s_nodes = {
    "control-plane" = {
      vcpu   = 2
      ram    = 8192
      disk   = 64
      cloud_init = "control-plane"
      longhorn_pool_name = ""  
      longhorn_pool_path = ""  
      longhorn_disk = ""
      longhorn_disk_size = 0
      ip_address = "192.168.1.80"
      hostname   = "msi-vm-control"
    }

    "kube-worker-node1" = {
      vcpu   = 4
      ram    = 16384
      disk   = 64
      cloud_init = "worker-node"
      longhorn_pool_name = "k3s_longhorn_node1"  
      longhorn_pool_path = "/mnt/node1"
      longhorn_disk = "kube-worker-node1"
      longhorn_disk_size = 333 # Size needs to match each worker node to ensure 100% functionality
      ip_address = "192.168.1.81"
      hostname   = "kube-worker-node1"
    }

    "kube-worker-node2" = {
      vcpu   = 4
      ram    = 16384
      disk   = 64
      cloud_init = "worker-node"
      longhorn_pool_name = "k3s_longhorn_node2"
      longhorn_pool_path = "/mnt/node2"
      longhorn_disk = "kube-worker-node2"
      longhorn_disk_size = 333 # Size needs to match each worker node to ensure 100% functionality
      ip_address = "192.168.1.82"
      hostname   = "kube-worker-node2"
    }

    "kube-worker-node3" = {
      vcpu   = 4
      ram    = 16384
      disk   = 64
      cloud_init = "worker-node"
      longhorn_pool_name = "k3s_longhorn_node3"
      longhorn_pool_path = "/mnt/node3"
      longhorn_disk = "kube-worker-node3"
      longhorn_disk_size = 333 # Size needs to match each worker node to ensure 100% functionality
      ip_address = "192.168.1.83"
      hostname   = "kube-worker-node3"
    }
  }