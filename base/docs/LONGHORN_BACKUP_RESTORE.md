# Restoring Volumes with Longhorn and Helm

This document explains how to back up and restore volumes in **Longhorn** using:
- A custom shell script: `longhorn-automation.sh`
- Backup metadata files (e.g., `backup_id_<APP_ID>.txt`)
- Helm chart overrides (e.g., `<APP_ID>-restored-volume.yaml`)
- Optional “wrapper” mode for partially generated Helm values

## 1. Prerequisites

1. **Longhorn** must be installed and running in your Kubernetes cluster.  
   - The Longhorn UI (e.g. [https://longhorn.exampleorg.com/#/backup#volume](https://longhorn.exampleorg.com/#/backup#volume)) should be accessible.
   
2. **Required CLI tools** on your local machine (or CI runner):
   - `jq`
   - `hcl2json`
   - `curl`
   - `bash` (with `set -euo pipefail` support)
   
3. **Credentials** to access the Longhorn API (stored securely in `.env` and in Bitwarden).

4. **Helm** installed and configured (v3+).

## 2. Environment & Credentials

All essential environment variables are loaded from `./terraform/.env`. For example:

```bash
# terraform/.env
LONGHORN_USER="admin"
LONGHORN_PASS="secret"
LONGHORN_MANAGER="longhorn.exampleorg.com"
BACKUP_BASE_URL="s3://exampleorg@minio.example.com/longhorn"
```

> **Note:** The actual credentials are stored in the **Telos Bitwarden Vault**. Make sure to populate `.env` with the correct user/password/endpoint.

## 3. The `longhorn-automation.sh` Script

Located in `base/scripts/longhorn-automation.sh` (or similar).  
**Usage**:
```bash
./longhorn-automation.sh {backup|restore} <app_id> [ORIGINAL_VOLUME_ID] [--wrapper]
```
- **`app_id`**: Identifier for your application/volume (e.g., `gitea-postgres-db`, `gitea-actions-docker`, etc.).
- **`ORIGINAL_VOLUME_ID`** (optional): If different from `<app_id>-pv`.
- **`--wrapper`** (optional flag): Writes a nested key in the generated restore manifest (useful for custom Helm chart wrappers).

**Key Outputs**:
- When backing up, the script stores a **Backup ID** in `./scripts/backup_id/backup_id_<APP_ID>.txt`.
- When restoring, the script generates a **Helm values** YAML file (e.g., `./helm/<APP_ID>-restored-volume.yaml`) which references the correct `fromBackup` URL.

### 3.1 Backup Flow

```bash
./longhorn-automation.sh backup <app_id>
```
1. **Creates a snapshot** in Longhorn via the API.
2. **Triggers a backup** of that snapshot.
3. **Waits** until the backup state is `Completed`.
4. **Stores the Backup ID** in `scripts/backup_id/backup_id_<app_id>.txt`.

### 3.2 Restore Flow

```bash
./longhorn-automation.sh restore <app_id> [ORIGINAL_VOLUME_ID] [--wrapper]
```
1. **Reads** the previously saved backup ID from `backup_id_<app_id>.txt`.
2. **Verifies** the backup is in `Completed` state (skipped if using a dummy ID).
3. **Generates** or updates a restore manifest (e.g., `<app_id>-restored-volume.yaml`) that sets `persistenceLonghorn.fromBackup`.

> **Note:** If `ORIGINAL_VOLUME_ID` is omitted, `<app_id>-pv` is used by default.

## 4. How to Back Up a Volume

1. **Set your environment**:
   - Ensure `LONGHORN_USER`, `LONGHORN_PASS`, `LONGHORN_MANAGER`, and `BACKUP_BASE_URL` are correct in `terraform/.env`.

2. **Run the backup command**:
   ```bash
   ./longhorn-automation.sh backup gitea-postgres-db
   ```
   - This creates a snapshot, starts a backup, and waits for completion.
   - Upon success, it writes the backup ID to `./scripts/backup_id/backup_id_gitea-postgres-db.txt`.

3. **Verify**:
   - Check `scripts/backup_id/backup_id_gitea-postgres-db.txt`.
   - Inspect the Longhorn UI to confirm the backup is marked `Completed`.

## 5. How to Restore a Volume

1. **Fetch or confirm** the backup ID is present in `scripts/backup_id/backup_id_<app_id>.txt`.  
   If the file is missing, the script uses `dummy-backup-id` and skips backup state validation.

2. **Run the restore command**:
   ```bash
   ./longhorn-automation.sh restore gitea-postgres-db --wrapper
   ```
   - This checks backup readiness, then generates `helm/gitea-postgres-db-restored-volume.yaml`.

3. **Include the generated file** in your **Helm** deployment.  
   For instance, add `--values helm/gitea-postgres-db-restored-volume.yaml` when installing or upgrading your chart.

> **Tip:** The `--wrapper` flag nests the `fromBackup:` under `<app_id>.persistenceLonghorn` instead of at the root. Adjust to match your chart structure.

## 6. Helm Integration Example

Many deployments handle persistent volumes via Helm. For example, in `deploy-gitea.sh`:

```bash
if [[ "${ENABLE_GITEA_POSTGRES_RESTORE:-false}" == "true" ]]; then
  echo "📦 Restoring Gitea PostgreSQL Volume..."
  base/scripts/longhorn-automation.sh restore gitea-postgres-db --wrapper

  echo "💾 Including PostgreSQL volume values in Helm release..."
  POSTGRES_RESTORE_VALUES="--values $HELM_VALUES_PATH/gitea-postgres-db-restored-volume.yaml"
else
  echo "⏩ Skipping PostgreSQL restore and volume config."
  POSTGRES_RESTORE_VALUES=""
fi

base/scripts/longhorn-automation.sh restore gitea
base/scripts/longhorn-automation.sh restore gitea-actions-docker --wrapper

helm upgrade --install gitea-volumes "$HELM_CHARTS_PATH/gitea-volumes" \
  --namespace gitea \
  --values "$HELM_VALUES_PATH/gitea-volumes-values.yaml" \
  --values "$HELM_VALUES_PATH/gitea-restored-volume.yaml" \
  --values "$HELM_VALUES_PATH/gitea-actions-docker-restored-volume.yaml" \
  $POSTGRES_RESTORE_VALUES
```

### 6.1 Example `gitea-postgres-db-restored-volume.yaml`

```yaml
gitea-postgres-db:
  persistenceLonghorn:
    fromBackup: "s3://exampleorg@minio.example.com/longhorn?backup=backup-673ee699e8e6417a&volume=gitea-postgres-db-pv"
```

### 6.2 Example Helm Chart Values for the Volume

```yaml
gitea-postgres-db:
  persistenceLonghorn:
    enabled: true
    restore: true
    pvcName: "gitea-postgres-db-pvc"
    pvName: "gitea-postgres-db-pv"
    size: "10Gi"
    accessMode: "ReadWriteOnce"
    reclaimPolicy: "Retain"
    storageClassName: "longhorn"
    csiDriver: "driver.longhorn.io"
    numberOfReplicas: 3
    frontend: blockdev
    backupTargetName: default
    fromBackup: "s3://exampleorg@minio.example.com/longhorn?backup=dummy_backup_id&volume=gitea-postgres-db-pv"
```

> Once the script writes the real `fromBackup` value, Helm will restore the volume from that backup.

---

## 7. Additional Notes

1. **Backup Strategy**  
   - The script defaults to `BACKUP_MODE="incremental"`.
   - Full backups can be enforced by changing the `BACKUP_MODE` variable in `longhorn-automation.sh`.

2. **Security**  
   - Store `LONGHORN_USER` and `LONGHORN_PASS` in a secure vault (Bitwarden).  
   - Keep `.env` files out of source control whenever possible.

3. **Debugging**  
   - Use `set -x` in your scripts to see the raw `curl` requests.  
   - Check the Longhorn UI to see if the snapshot/backup was created successfully.

4. **Version Control**  
   - Recommended to commit the final Helm overrides (`-restored-volume.yaml`) but **not** the actual `backup_id_<APP_ID>.txt` files (unless you want them versioned). 
   - Keep the `.env` file out of version control to protect credentials.

---

## 8. FAQ

**Q:** What if I don’t have a backup ID?  
**A:** The script will use a dummy ID, skip validation, and set `fromBackup=dummy_backup_id`. This will not restore real data; it’s purely for a placeholder scenario.

**Q:** How do I restore with a different original volume name?  
**A:** Provide it as the third argument: `./longhorn-automation.sh restore gitea-postgres-db some-other-volume-id --wrapper`.

**Q:** How do I see if the backup is valid?  
**A:** The script queries Longhorn for the backup status. You can also check the Longhorn UI under **Backups** → **Backup Volumes**.

---

**That’s it!** With this workflow:
1. **Backup**: `longhorn-automation.sh backup <app_id>`  
2. **Restore**: `longhorn-automation.sh restore <app_id> [--wrapper]`  
3. **Deploy** via Helm with the generated YAML overrides.  
