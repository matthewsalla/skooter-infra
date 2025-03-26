#!/bin/bash
# This script automates the installation and configuration steps for preparing an Ubuntu 24.04 LTS server
# for virtualization (qemu-kvm, libvirt) and Terraform installation, including creating a bridged network interface (bri0)
# on top of the wired adapter enp3s0.
#
# IMPORTANT:
# - Review and adjust the network configuration below to match your actual network details.
# - The SSH key copy and terraform.tfvars steps are mentioned as guidance; adjust as needed.
# - Some changes (like group membership) may require you to log out and log back in.

set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (or via sudo)."
  exit 1
fi

HOST_IP="192.168.1.222"
GATEWAY_IP="192.168.1.1"
NETWORK_INTERFACE="enp3s0"

echo "Starting system update and upgrade..."
apt update && apt upgrade -y

###############################
# 1. Install Basic Dependencies
###############################
echo "Installing basic packages: gnupg, software-properties-common, curl, and ubuntu-drivers-common..."
apt install -y gnupg software-properties-common curl ubuntu-drivers-common

###############################
# 2. Add HashiCorp Repository for Terraform
###############################
echo "Adding HashiCorp GPG key and repository..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list

apt update

###############################
# 3. Install Virtualization Tools and Terraform
###############################
echo "Installing virtualization tools, Terraform, and other utilities..."
apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst cloud-image-utils python3-libvirt terraform wget unzip

# (Optional) Reinstall libvirt-daemon-system if needed
apt install -y libvirt-daemon-system

###############################
# 4. Enable and Start Libvirt Service
###############################
echo "Enabling and starting libvirtd..."
systemctl enable --now libvirtd
systemctl restart libvirtd

###############################
# 5. Add User to libvirt and kvm Groups
###############################
# If the script is run via sudo, use $SUDO_USER; otherwise, use the current user.
TARGET_USER="${SUDO_USER:-$(whoami)}"
echo "Adding user ${TARGET_USER} to libvirt and kvm groups..."
usermod -aG libvirt,kvm "${TARGET_USER}"

echo "NOTE: You may need to log out and log back in (or reboot) for the group changes to take effect."

###############################
# 6. (Optional) SSH Key Copy
###############################
# If you need to copy your SSH key to a remote host, uncomment and modify the following line:
# ssh-copy-id -i ~/.ssh/id_rsa.pub atlasmalt@192.168.14.231

###############################
# 7. Update terraform.tfvars
###############################
# Ensure that you have updated your terraform.tfvars file with the proper values:
# host_ip, cluster_pool, cluster_pool_name, vcpu, ram, ip_address, hostname
# (You may copy or move your file as needed.)

###############################
# 8. Configure Libvirt (qemu.conf)
###############################
echo "Configuring /etc/libvirt/qemu.conf to set security_driver = \"none\"..."
if [ -f /etc/libvirt/qemu.conf ]; then
  sed -i 's/^#\?security_driver\s*=.*/security_driver = "none"/' /etc/libvirt/qemu.conf
else
  echo 'security_driver = "none"' > /etc/libvirt/qemu.conf
fi

echo "Restarting libvirtd to apply changes..."
systemctl restart libvirtd

###############################
# 9. Configure Storage Pool for K3s Cluster
###############################
echo "Ensuring storage pool directory exists and has proper permissions..."
mkdir -p /var/lib/libvirt/images
chown libvirt-qemu:kvm /var/lib/libvirt/images
chmod 755 /var/lib/libvirt/images
# Set k3s_cluster_main_pool variable as needed in your Terraform or cluster config.

###############################
# 10. Configure Network with Bridge (bri0)
###############################
echo "Backing up current netplan configuration and writing new bridged network config..."
NETPLAN_FILE="/etc/netplan/50-bridge.yaml"
if [ -f "${NETPLAN_FILE}" ]; then
  cp "${NETPLAN_FILE}" "${NETPLAN_FILE}.bak.$(date +%F-%T)"
fi

# Create the bridged network configuration for enp3s0.
# - The physical interface enp3s0 is marked as optional.
# - The bridge bri0 is configured with a static IP, default route (via 'routes'), and nameservers.
cat > "${NETPLAN_FILE}" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ${NETWORK_INTERFACE}:
      dhcp4: no
      optional: true
  bridges:
    bri0:
      interfaces: [${NETWORK_INTERFACE}]
      dhcp4: no
      addresses:
        - ${HOST_IP}/24
      routes:
        - to: default
          via: ${GATEWAY_IP}
      nameservers:
        addresses:
          - 1.1.1.1
          - 8.8.8.8
EOF


# Restrict file permissions to avoid warnings.
chmod 600 "${NETPLAN_FILE}"

echo "Applying new netplan configuration..."
netplan apply

###############################
# 11. Disable Laptop Power Settings (Lid Switch)
###############################
echo "Configuring /etc/systemd/logind.conf for power management..."
sed -i 's/^#*HandleLidSwitch=.*/HandleLidSwitch=ignore/' /etc/systemd/logind.conf
sed -i 's/^#*HandleLidSwitchExternalPower=.*/HandleLidSwitchExternalPower=ignore/' /etc/systemd/logind.conf
sed -i 's/^#*HandleLidSwitchDocked=.*/HandleLidSwitchDocked=ignore/' /etc/systemd/logind.conf

echo "Restarting systemd-logind..."
systemctl restart systemd-logind

###############################
# 12. (Optional) Install pipx and Glances for Monitoring
###############################
echo "Installing pipx and glances for system monitoring..."
apt install -y pipx
pipx install "glances[web]" --force
pipx ensurepath
# To start glances in web mode, run: glances -w

echo "Setup complete. Please log out and log back in for all group changes to take effect."
