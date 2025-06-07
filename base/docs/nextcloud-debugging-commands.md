---

## ✅ OnlyOffice Integration Debug & Validation Guide

This guide documents key `kubectl` and helper commands to validate and debug the OnlyOffice + Nextcloud setup in your K3s/Kubernetes environment.

---

### 🛠️ Validate JWT Environment in OnlyOffice Pods

Check that the JWT-related environment variables are present and identical across all OnlyOffice containers:

```bash
# Docservice (primary backend)
kubectl -n nextcloud exec deploy/docservice -c docservice -- env | grep JWT

# Converter (document rendering)
kubectl -n nextcloud exec deploy/converter -c converter -- env | grep JWT

# Documentserver (sometimes a combined pod)
kubectl -n nextcloud exec deploy/documentserver -c documentserver -- env | grep JWT
```

---

### 🧪 Test HTTP Connectivity Between OnlyOffice and Nextcloud

Ensure documentserver can reach Nextcloud via its public and internal URLs:

```bash
# From docservice pod
kubectl -n nextcloud exec deploy/docservice -c docservice -- \
  wget -qO- --no-check-certificate https://nextcloud.telos.company/status.php

# Or using internal service URL
kubectl -n nextcloud exec deploy/docservice -c docservice -- \
  wget -qO- http://nextcloud:8080/status.php
```

---

### ⚙️ Check OnlyOffice App Settings in Nextcloud

Use `occ` to view and manage Nextcloud’s OnlyOffice app config:

```bash
# View current OnlyOffice config
kubectl -n nextcloud exec deploy/nextcloud -c nextcloud -- \
  su -s /bin/sh www-data -c 'php occ config:list onlyoffice'
```

Expected values (minimally):

* `DocumentServerUrl`: `https://onlyoffice.telos.company`
* `DocumentServerInternalUrl`: `http://documentserver`
* `StorageUrl`: `http://nextcloud:8080`
* `jwt_secret`: (secret value)
* `verify_peer_off`: `"true"`
* `jwt_enabled`: `"true"`

---

### ⚙️ Set or Fix Config with `occ`

Minimal command set to configure OnlyOffice:

```bash
# Get JWT from Kubernetes secret
JWT_SECRET=$(kubectl get secret onlyoffice-creds -n nextcloud -o jsonpath='{.data.JWT_SECRET}' | base64 --decode)

# Apply config (adjust POD name if needed)
POD=$(kubectl get pod -n nextcloud -l app.kubernetes.io/name=nextcloud -o jsonpath='{.items[0].metadata.name}')
kubectl -n nextcloud exec "$POD" -c nextcloud -- su -s /bin/bash www-data -c \
  "php occ config:app:set onlyoffice DocumentServerUrl --value='https://onlyoffice.telos.company'"
kubectl -n nextcloud exec "$POD" -c nextcloud -- su -s /bin/bash www-data -c \
  "php occ config:app:set onlyoffice DocumentServerInternalUrl --value='http://documentserver'"
kubectl -n nextcloud exec "$POD" -c nextcloud -- su -s /bin/bash www-data -c \
  "php occ config:app:set onlyoffice StorageUrl --value='http://nextcloud:8080'"
kubectl -n nextcloud exec "$POD" -c nextcloud -- su -s /bin/bash www-data -c \
  "php occ config:app:set onlyoffice jwt_secret --value='$JWT_SECRET'"
kubectl -n nextcloud exec "$POD" -c nextcloud -- su -s /bin/bash www-data -c \
  "php occ config:app:set onlyoffice verify_peer_off --value='true'"
kubectl -n nextcloud exec "$POD" -c nextcloud -- su -s /bin/bash www-data -c \
  "php occ config:app:set onlyoffice jwt_enabled --value='true'"
```

---

### 🔁 Restart Pods (Optional)

If needed, restart deployments to re-read secret values or config:

```bash
kubectl rollout restart deployment -n nextcloud docservice
kubectl rollout restart deployment -n nextcloud converter
kubectl rollout restart deployment -n nextcloud documentserver
kubectl rollout restart deployment -n nextcloud nextcloud
```

---
