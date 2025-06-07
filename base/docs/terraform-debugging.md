## 1. Verify Terraform / libvirt side  
1. **Confirm the libvirt volume was created**  
   ```bash
   terraform state list | grep longhorn_disks
   # you should see something like
   # libvirt_volume.longhorn_disks["telos-kube-vm-worker-node4"]
   ```
2. **Check the pool and volume on the host**  
   ```bash
   virsh pool-list             # should list your longhorn_pools (e.g. telos_longhorn_node4)
   virsh vol-list <pool-name>  # e.g. virsh vol-list telos_longhorn_node4
   # ensure telos-longhorn-node4.qcow2 appears with the correct size
   ```
3. **Inspect the domain XML**  
   ```bash
   virsh dumpxml telos-kube-vm-worker-node4 | xmllint --format -
   ```
   - Under `<devices>…<disk>` you should see your qcow2 volume attached as a virtio disk.

If any of the above is missing, re-run `terraform apply` (or target the volume and domain) until the disk appears.

---

## 2. Inside the new VM  
Once you’ve confirmed libvirt is serving the disk, SSH in:

```bash
ssh ubuntu@192.168.14.<node4_ip>
```

### a) List block devices  
```bash
lsblk -nd -o NAME,SIZE,MODEL
```
- You should see a device (e.g. `vdb` or `nvme1n1`) matching your `longhorn_disk_size` (e.g. ~222G or whatever you set).  
- If it’s missing, libvirt didn’t attach it.

### b) Inspect dmesg for disk events  
```bash
dmesg | tail -n 30
```
- Look for “virtio-blk virtioX:…” or new disk registration messages.
- Any errors (I/O, device offline) will show here.

### c) Check cloud-init logs  
```bash
sudo cat /var/log/cloud-init-output.log | grep -i longhorn -A5
```
- This is where your `mkfs.ext4` and fstab lines run.
- Verify that `${longhorn_disk_size}` was correctly substituted (not blank or zero).
- Look for errors like “No such device” or “mkfs: command not found.”

---

## 3. Validate fstab & mount  
```bash
grep longhorn /etc/fstab
# you should see something like:
/dev/vdb  /var/lib/longhorn  ext4  defaults  0 0
```
If it’s missing or malformed, cloud-init didn’t append it.

Then:

```bash
sudo mount -a
mount | grep /var/lib/longhorn
```
- If the mount fails, note the error and correct the device name in `/etc/fstab`.

---

## 4. Manual attach & format (if automation failed)  
If you need a quick workaround while you debug cloud-init:

1. **Identify the disk**  
   ```bash
   sudo lsblk
   ```
2. **Format**  
   ```bash
   sudo mkfs.ext4 -F /dev/vdb   # replace vdb with your disk
   ```
3. **Create mountpoint & mount**  
   ```bash
   sudo mkdir -p /var/lib/longhorn
   echo "/dev/vdb /var/lib/longhorn ext4 defaults 0 0" | sudo tee -a /etc/fstab
   sudo mount -a
   ```
4. **Restart K3s agent** (to re-trigger the `--node-label=node.longhorn.io/create-default-disk=true` logic)  
   ```bash
   sudo systemctl restart k3s-agent
   ```

---

## 5. Check Kubernetes & Longhorn  
1. **Ensure the node has the Longhorn label**  
   ```bash
   kubectl get node telos-kube-vm-worker-node4 --show-labels
   ```
   - Look for `node.longhorn.io/create-default-disk=true`.  
   - If missing, add it:
     ```bash
     kubectl label node telos-kube-vm-worker-node4 node.longhorn.io/create-default-disk=true
     ```
2. **Inspect Longhorn’s UI / CRDs**  
   ```bash
   # in the longhorn namespace:
   kubectl -n longhorn-system get nodes.longhorn.io
   kubectl -n longhorn-system describe nodes.longhorn.io telos-kube-vm-worker-node4
   ```
   - You should see the “Storage Available” pool under that node.
3. **Trigger default disk creation**  
   - In the Longhorn UI → **Settings** → “Automatically create default disk” should be on.  
   - Or, in each node’s CR, under `.spec.disks`, you can manually add a disk entry pointing to `/var/lib/longhorn`.

---

### Summary
1. **Host-level**: confirm Terraform/libvirt actually made & attached the new qcow2.  
2. **VM-level**: check `lsblk`, cloud-init logs, dmesg, fstab, and either fix cloud-init or manually format & mount.  
3. **K8s-level**: ensure the node label is set so Longhorn picks up `/var/lib/longhorn` as a storage disk.

Work through these in order, and you’ll quickly see whether the problem is in Terraform, cloud-init, or the K3s/Longhorn layer. Let me know which step uncovers the culprit!