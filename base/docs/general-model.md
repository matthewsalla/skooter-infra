# 🧠 Skooter Conceptual Model  
> A complete breakdown of how the **Thin Repo** and **Base Repo** work together to manage infrastructure, Kubernetes deployments, secrets, and Helm configuration.

---

## 🧱 Thin Repo: Environment-Specific Configuration

The **thin repo** represents a specific cluster or environment. It contains:

- Secrets
- Helm values
- Cluster-specific overrides
- `.env` and `terraform.tfvars` files

### 🌲 Thin Repo Directory Tree (Simplified)
```
thin-repo/
├── base/                       # Git submodule to skooter-base (read-only)
├── helm/                      # All Helm values.yaml overrides
│   ├── mealie-values.yaml
│   ├── staging/
│   └── prod/
├── kubernetes/                # Thin-specific post-deploy manifests
│   └── manifests/
├── scripts/                   # Thin repo utilities and backups
│   ├── backup_id/             # Stores backup IDs per app
│   ├── config.sh              # Sets env vars like CERT_ISSUER, THIN_ROOT
├── secrets/                   # All sealed secrets
│   └── *.sealed-secret.yaml
├── terraform/
│   └── terraform.tfvars       # Cluster-specific config
├── deploy.sh                  # Entry point (calls into base scripts)
└── .env                       # Central credentials + secrets
```

---

## 🧰 Base Repo (`skooter-base`): Reusable Infrastructure Logic

The **base repo** is a general-purpose toolbox for deploying any environment.

### 🔁 Usage: `git submodule add git@github.com:... skooter-base.git base`

### 🧭 Base Repo Tree (Simplified)
```
base/
├── helm-charts/               # Reusable Helm charts for all apps
│   ├── mealie/
│   ├── gitea/
│   └── ...
├── kubernetes/
│   └── manifests/             # Middleware, Longhorn tuning templates
├── scripts/
│   ├── deploy-*.sh            # Modular deploy scripts (called from thin)
│   ├── longhorn-automation.sh # Backup/restore Longhorn volumes
├── terraform/
│   ├── main.tf, provider.tf   # Shared cluster provisioning logic
│   ├── scripts/
│   │   └── nuke-deploy-cluster.sh
└── README.md
```

---

## 🔁 Execution Flow

### 1. **Cluster Deployment**

```bash
./deploy.sh                      # From thin repo root
  └── cd base/terraform/
      └── terraform apply       # Using thin repo's terraform.tfvars
  └── bash base/scripts/deploy-sealed-secrets.sh
  └── bash base/scripts/deploy-longhorn.sh
  └── ...
```

### 2. **Secret Management**
- Thin repo provides `secrets/*.sealed-secret.yaml`
- Private key is restored via `restore-sealed-secrets.sh` (Bitwarden or PEM)

### 3. **Helm Deployments**
- Base contains reusable Helm charts.
- Thin repo provides `helm/*.yaml` values files.

```bash
helm upgrade --install mealie base/helm-charts/mealie \
  --values helm/mealie-values.yaml
```

### 4. **Backup / Restore Flow**

```bash
bash base/scripts/longhorn-automation.sh backup mealie
  └── Reads from .env and writes to scripts/backup_id/

bash base/scripts/longhorn-automation.sh restore mealie
  └── Writes restored volume yaml to helm override
```

---

## 🔐 Config Loading Convention

All base scripts:
```bash
# Will attempt to load thin repo config automatically
if [ -f "$THIN_ROOT/scripts/config.sh" ]; then
  source "$THIN_ROOT/scripts/config.sh"
fi
```

Thin repo must define `THIN_ROOT` before calling base scripts, or the scripts must infer it dynamically based on traversal.

---

## 🔁 Git Submodule Lifecycle

### Add
```bash
git submodule add git@github.com:your-org/skooter-base.git base
git submodule update --init --recursive
```

### Update
```bash
git submodule update --remote base
```

### Clone Thin Repo with Submodule
```bash
git clone --recursive https://github.com/your-org/example-infra.git
```

---

## 🧠 Summary: Who Owns What?

| Responsibility                        | Owned By     | Folder            |
|--------------------------------------|--------------|-------------------|
| Secrets                              | Thin Repo    | `secrets/`        |
| Helm values per environment          | Thin Repo    | `helm/`           |
| Terraform configuration              | Thin Repo    | `terraform/`      |
| Backup IDs                           | Thin Repo    | `scripts/backup_id/` |
| Helm charts                          | Base Repo    | `base/helm-charts/` |
| Kubernetes post-install manifests    | Base Repo    | `base/kubernetes/`  |
| Core scripts & orchestration logic   | Base Repo    | `base/scripts/`   |
| Terraform modules and logic          | Base Repo    | `base/terraform/` |
