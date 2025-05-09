# skooter-infra
Bolt on infrastructure parts for the Skooter Base

## 🧱 PHASE 1: Create Your Thin Repo from the Template

This is **one-time setup** to take your `skooter-infra` GitHub template and use it to seed your `skooter-example-org-infra` thin repo in Gitea.

---

### ✅ Step 1: Clone the GitHub template repo (run this on your Mac)

```bash
git clone git@github.com:matthewsalla/skooter-infra.git
cd skooter-infra
```

This gives you a clean copy of the latest template.

---

### ✅ Step 2: Rename `origin` to `upstream` (still inside the template folder)

```bash
git remote rename origin upstream
```

This tells Git: "GitHub is the upstream template now."

---

### ✅ Step 3: Point to your **Gitea thin repo** as the new `origin`

```bash
git remote add origin git@git.github.com:exampleorg/skooter-example-org-infra.git
```

Now your Git remotes look like this:

```bash
git remote -v
```

```
origin    git@git.github.com:exampleorg/skooter-example-org-infra.git
upstream  git@github.com:matthewsalla/skooter-infra.git
```

---

### ✅ Step 4: Push the repo to Gitea to initialize your thin repo

```bash
git push -u origin main
```

Now your Gitea thin repo (`skooter-example-org-infra`) has all the files from the GitHub template.

You can now **delete this local clone** (or just move on).

---

## 🔁 PHASE 2: Future Updates (when you want to pull updates from the template)

Let’s say in a few days or weeks, you make updates to your GitHub `skooter-infra` repo and want those updates in your **thin repo** (in Gitea).

### ✅ Step 1: Clone your thin repo (from Gitea)

```bash
git clone git@git.github.com:exampleorg/skooter-example-org-infra.git
cd skooter-example-org-infra
git submodule update --init --recursive
```

---

### ✅ Step 2: Add the GitHub template as `upstream`

```bash
git remote add upstream git@github.com:matthewsalla/skooter-infra.git
git fetch upstream
```

---

### ✅ Step 3: Pull in updates from upstream

```bash
git merge upstream/main
```

Resolve any conflicts (if any), test, then:

```bash
git push origin main
```

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
