variable "ubuntu_image_url" {
  default = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

variable "libvirt_user" {
  type        = string
  description = "username used for logging into libvirtd with SSH"
}

variable "k3s_cluster_main_pool" {
  type        = string
  description = "Main storage pool for all nodes"
}

variable "k3s_cluster_main_pool_name" {
  type        = string
  description = "Main storage pool name for all nodes"
}

variable "k3s_cluster_base_pool" {
  type        = string
  description = "Base Images storage pool for all nodes"
}

variable "k3s_cluster_base_pool_name" {
  type        = string
  description = "Base images storage pool name for all nodes"
}

variable "gateway_ip" {
  type        = string
  description = "IP address of the Gateway (typically the router)"
}

variable "k3s_public_domain" {
  type        = string
  description = "Public domain of the K3s Cluster"
}

variable "host_ip" {
  type        = string
  description = "IP address of the Host"
}

# Uses default public key for SSH access to VMs
variable "ssh_key" {
  type  = string
  default = "~/.ssh/id_rsa.pub"
}

variable "k3s_nodes" {
  type = map(object({
    vcpu              = number
    ram               = number
    disk              = number
    cloud_init        = string  # e.g. "control-plane" or "worker-node"
    longhorn_pool_name = string
    longhorn_pool_path = string
    longhorn_disk = string # If non-empty, create & attach a 1TB disk
    longhorn_disk_size = number
    ip_address        = string
    hostname          = string
  }))
}
