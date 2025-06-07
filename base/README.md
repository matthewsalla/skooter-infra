```markdown
# 🛠️ Skooter Base Repo

This repository contains the **shared base infrastructure and Kubernetes tooling** for use across multiple thin repositories. It is designed to be consumed as a **Git submodule** and includes:

- 🐳 Terraform provisioning scripts  
- ☸️ Kubernetes deployment helpers  
- 💾 Longhorn automation utilities  
- 🧩 Modular Helm-based app install scripts

The goal is to **centralize reusable logic**, while thin repos (e.g., `example-infra`, `msi-laptop-infra`) handle environment-specific overrides like `values.yaml`, secrets, domain names, and organizational logic.

---

## 📦 Submodule Setup

To add the `skooter-base` repo as a submodule:

```bash
git submodule add git@github.com:matthewsalla/skooter-base.git base
git submodule update --init --recursive
git add .gitmodules base
```

> 🔁 Always use `--recursive` to ensure any nested submodules are also pulled.

---

## 📥 Pulling Base Updates

When changes are made to `skooter-base` (such as improvements to Terraform or deployment scripts), you can pull in updates from your thin repo by running:

```bash
git submodule update --remote base
```

---

## 🚀 Cloning Thin Repos with Base Included

If you're cloning a thin repo (like `example-infra` or `msi-laptop-infra`), you **must use the recursive flag** to pull the base submodule:

```bash
# ✅ Correct
git clone --recursive https://github.com/yourusername/example-infra.git

# 🛑 If you forget:
git submodule update --init --recursive
```

---

## 📦 Cloning Thin Repo and Checking Out a Feature Branch in the Submodule

```bash
# Clone the thin repo and initialize submodules
git clone --recurse-submodules <your-thin-repo-url>
cd <your-thin-repo-folder>

# OR if already cloned, just initialize the submodule
git submodule update --init --recursive

# Go into the submodule directory
cd base

# Fetch all remote branches
git fetch origin

# Checkout the desired feature branch in the submodule
git checkout feature/deploy-gitea-stock

# (Optional but recommended) Pull the latest changes for the feature branch
git pull origin feature/deploy-gitea-stock

# Go back to the thin repo root
cd ..

# Record the submodule branch update in the thin repo
git add base
git commit -m "Point submodule to feature/deploy-gitea-stock"
```

---

## 🛠 Updating an Existing Repo to Track a Feature Branch in the Submodule

If your submodule was already initialized and you just want to switch to the feature branch:

```bash
cd base
git fetch origin
git checkout feature/deploy-gitea-stock
git pull origin feature/deploy-gitea-stock
cd ..
git add base
git commit -m "Update submodule to feature/deploy-gitea-stock"
```


---

## 🧠 Pro Tips

- Store thin repo-specific configuration (like `.env`, `terraform.tfvars`, and sealed secrets) **in the thin repo**, not here.
- Scripts in `skooter-base` will expect a `THIN_ROOT` environment variable when called from the thin repo. This allows them to find `.env` and secrets reliably across repo boundaries.
- You can safely call scripts like `longhorn-automation.sh` manually, or have them orchestrated by thin repo deploy flows.
