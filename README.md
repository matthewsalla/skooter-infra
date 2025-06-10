# skooter-infra

Here is your cleaned-up and updated `README.md`, with all unnecessary sections removed and a new concise guide focused solely on using `skooter.sh` for onboarding:

---

````markdown
# skooter-infra

Bolt-on infrastructure parts for the Skooter Base.

---

## 🚀 Onboarding a New Customer

Use the `skooter.sh` script to initialize and manage your customer-specific Skooter infra repository.

---

### 📥 Step 1: Download the Script

Run this in the directory where you want to manage Skooter repos:

```bash
curl -O https://raw.githubusercontent.com/matthewsalla/skooter-infra/main/skooter.sh
chmod +x skooter.sh
````

---

### ⚙️ Step 2: Run the Script

#### 🟢 First-Time Setup (`init`)

This pushes a copy of the Skooter infra code into your private Gitea repository.

```bash
./skooter.sh init
```

#### 🔁 Updating from Template (`update`)

This pulls the latest template changes into your existing Gitea repo clone.

```bash
./skooter.sh update
```

---

### 📂 What It Does

The script will create **two folders** in your current working directory:

* One for the **template content** (used temporarily during `init`)
* One for the **customer-specific repo** (your actual working directory)

---

### 🔐 Requirements

* Git must be installed
* SSH access to your private Gitea repository
* Gitea repo must already exist and be accessible via SSH

---

### 📝 Example

```bash
./skooter.sh init
# => Creates: ./skooter-infra/ and pushes to Gitea

./skooter.sh update
# => Creates: ./skooter-example-org-infra/ and merges latest template changes
```

You are now ready to work in the customer-specific infra repo.

---

## ✅ Visual Summary

```text
[GitHub: skooter-infra]       ← (template)
       ↓
  git clone + push to →
       ↓
[Gitea: skooter-example-org-infra] ← (thin repo you work in daily)

Then later:

[Gitea thin repo]
   ↑
 git fetch upstream
 git merge upstream/main  ← (bring in new template changes)
```

# 🗂️ Terraform Remote State – MinIO S3

This setup configures Terraform to store state in a private **MinIO** S3 bucket using `backend.hcl`.

---

## 🔧 Backend Details

- **Bucket**: `terraform`  
- **Key**: `terraform.tfstate`  
- **Endpoint**: `http://192.168.14.222:9900`  
- **Auth**: Access key/secret (e.g. `terraform / SuperSecretPassword123`)

---

## 📁 File Structure

```plaintext
terraform/
├── backend.hcl     # MinIO S3 backend settings
├── README.md       # This file
```

---

## 🚀 Usage

Run from your base module directory:

```bash
cd base/terraform

terraform init \
  -backend-config=../../terraform/backend.hcl \
  -reconfigure
```

---

## 🧾 backend.hcl Example

```hcl
bucket                      = "terraform"
key                         = "terraform.tfstate"
region                      = "us-east-1"

access_key                  = "terraform"
secret_key                  = "SuperSecretPassword123"
endpoints                   = { s3 = "http://192.168.14.222:9900" }
use_path_style              = true

skip_region_validation      = true
skip_credentials_validation = true
skip_metadata_api_check     = true
skip_requesting_account_id  = true
```

---

## 🛡️ Tips

- ✅ Use `readwrite` policy in MinIO for the `terraform` user  
- 🔐 Replace hardcoded creds with env vars for production  
- 🧪 Validate state with:

  ```bash
  aws --endpoint-url http://192.168.14.222:9900 s3 ls s3://terraform/
  ```

---
---
