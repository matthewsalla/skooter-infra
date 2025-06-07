# XSLT Transform Smoke Test

This directory lets you rapidly verify changes to `config/memory_backing.xslt` without touching your production Terraform stack.

## Prerequisites

- Terraform & the `terraform-provider-libvirt` plugin installed  
- Local `virsh` client (e.g. via Homebrew: `brew install libvirt`)  
- SSH access to your libvirt host at `192.168.14.231` as user `atlasmalt`

## Usage

From this folder:

```bash
# 1) Initialize the test
terraform init

# 2) Apply the tiny VM
terraform apply -var-file=../../../terraform/terraform.tfvars --auto-approve

# 3) Dump the transformed XML locally:
virsh -c 'qemu+ssh://atlasmalt@192.168.14.231/system?no_verify=1' \
     dumpxml test-transform > after.xml

# 4) Inspect `after.xml` for your <cpu .../> and <memoryBacking> sections

# 5) Tear it down
terraform destroy -var-file=../../../terraform/terraform.tfvars --auto-approve
