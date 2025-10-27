---
title: Migrating Longhorn Backup from MinIO to Garage After Docker Image Discontinuation
date: 2025-10-27 10:00:00 +0200
categories: [storage, kubernetes]
description: A step-by-step guide to migrating Longhorn backup storage from MinIO to Garage after MinIO discontinued their Docker images. Learn how to set up Garage as an S3-compatible backup target for your Kubernetes cluster.
image:
  path: /assets/img/posts/garage.webp
  alt: Garage S3 Storage for Longhorn Backups
---

When MinIO recently announced they're discontinuing Docker images and moving to a source-only distribution model, many homelab users were left scrambling for alternatives. With hundreds of thousands of installations potentially running outdated versions with known CVEs, it was time to find a more reliable solution.

Enter Garage - a self-hosted, S3-compatible, distributed object storage service that's perfect for Kubernetes backup storage.


> **Note:** If you're looking for information on how to restore from Longhorn backups after migrating to Garage, check out my previous guide on [Restoring from Longhorn Backups](/blog/longhorn-backup-restore/). The restoration process remains identical regardless of whether you're using MinIO or Garage as your S3 backend.
{: .prompt-info }

## Why Garage?

After MinIO's controversial decision to drop Docker support (Issue #21647), I needed a drop-in S3-compatible replacement that:
- Has active Docker image support
- Is lightweight enough for homelab use
- Provides reliable S3 API compatibility
- Works seamlessly with Longhorn backups

Garage checked all these boxes.

## Prerequisites

- Ubuntu server with Docker and Docker Compose
- Kubernetes cluster with Longhorn installed
- Flux CD for GitOps (optional, but recommended)

## Setting Up Garage

### 1. Directory Structure
```bash
sudo mkdir -p /srv/docker/garage/{meta,data}
cd /srv/docker/garage
```

### 2. Generate Secrets
```bash
# Generate RPC secret for internal communication
openssl rand -hex 32

# Generate admin token for WebUI
openssl rand -hex 32
```

### 3. Create Configuration

Create `/srv/docker/garage/garage.toml`:
```toml
metadata_dir = "/var/lib/garage/meta"
data_dir = "/var/lib/garage/data"
db_engine = "lmdb"

replication_factor = 1

rpc_bind_addr = "0.0.0.0:3901"
rpc_public_addr = "127.0.0.1:3901"
rpc_secret = "YOUR_RPC_SECRET_HERE"

[s3_api]
s3_region = "us-east-1"
api_bind_addr = "0.0.0.0:3900"
root_domain = ".s3.garage"

[admin]
api_bind_addr = "0.0.0.0:3903"
admin_token = "YOUR_ADMIN_TOKEN_HERE"
```

> For single-node deployments, `replication_factor = 1` is sufficient. Multi-node clusters should use 3 for redundancy.
{: .prompt-tip }

### 4. Docker Compose Setup

Create `/srv/docker/garage/docker-compose.yml`:
```yaml
version: "3"
services:
  garage:
    image: dxflrs/garage:v2.1.0
    container_name: garage
    network_mode: "host"
    restart: unless-stopped
    volumes:
      - ./garage.toml:/etc/garage.toml
      - ./meta:/var/lib/garage/meta
      - ./data:/var/lib/garage/data

  webui:
    image: khairul169/garage-webui:latest
    container_name: garage-webui
    restart: unless-stopped
    volumes:
      - ./garage.toml:/etc/garage.toml:ro
    environment:
      API_BASE_URL: "http://127.0.0.1:3903"
      S3_ENDPOINT_URL: "http://127.0.0.1:3900"
    network_mode: "host"
```

### 5. Start Services
```bash
docker-compose up -d
```

## Configuring Garage Storage

### 1. Initialize Node Layout
```bash
# Create alias for easier command execution
alias garage="docker exec -ti garage /garage"

# Get node ID
garage node id

# Assign storage capacity (adjust based on your available space)
garage layout assign <node-id> -z default -c 100G

# Apply layout
garage layout show
garage layout apply --version 1
```

### 2. Create Bucket and Credentials
```bash
# Create bucket for Longhorn backups
garage bucket create longhorn

# Create access key
garage key create longhorn-key

# Grant permissions
garage bucket allow longhorn --read --write --owner --key longhorn-key

# View credentials (note the Key ID and Secret key)
garage key info longhorn-key --show-secret
```

## Integrating with Longhorn

### 1. Create Kubernetes Secret

Update your SOPS-encrypted secret or create a new one:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: minio-secret
  namespace: longhorn-system
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: <Key-ID-from-garage>
  AWS_SECRET_ACCESS_KEY: <Secret-Key-from-garage>
  AWS_ENDPOINTS: http://<GARAGE_SERVER_IP>:3900
  AWS_REGION: us-east-1
```

Apply the secret:
```bash
kubectl apply -f minio-secret.yaml
```

### 2. Update Longhorn HelmRelease
```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: longhorn
  namespace: longhorn-system
spec:
  interval: 1h
  url: https://charts.longhorn.io
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: longhorn
spec:
  interval: 1h
  chart:
    spec:
      chart: longhorn
      version: 1.10.0
      sourceRef:
        kind: HelmRepository
        name: longhorn
        namespace: longhorn-system
  values:
    defaultSettings:
      backupTarget: "s3://longhorn@us-east-1/"
      backupTargetCredentialSecret: "minio-secret"
      backupstorePollInterval: "300"
      # ... other settings
```

> In Longhorn 1.10.0+, backup settings are under `defaultSettings`, not a separate `defaultBackupStore` section.
{: .prompt-warning }

## Testing the Setup

### 1. Verify Connectivity

Access the Garage WebUI at `http://<SERVER_IP>:3909` to verify the node is connected and healthy.

### 2. Test Backup from Longhorn

1. Navigate to Longhorn UI → Volume
2. Select a volume → Create Backup
3. Monitor the backup progress
4. Verify the backup appears in Garage WebUI under the `longhorn` bucket

### 3. CLI Verification
```bash
# List buckets
garage bucket list

# View bucket info
garage bucket info longhorn
```

## Troubleshooting

### WebUI Shows "Unknown Error"

Ensure the `[admin]` section is present in `garage.toml` and the container is restarted:
```bash
docker-compose restart
docker logs garage
```

### Connection Refused on Port 3903

Check if the admin API is listening:
```bash
netstat -tlnp | grep 3903
```

### Longhorn Can't Connect to Garage

Verify network connectivity from Kubernetes cluster:
```bash
kubectl run -it --rm debug --image=amazon/aws-cli --restart=Never -- \
  s3 ls s3://longhorn --endpoint-url http://<GARAGE_IP>:3900
```

## Benefits of This Migration

- **Active maintenance**: Garage continues to provide Docker images and updates
- **Lightweight**: Lower resource footprint compared to MinIO
- **S3 compatible**: Drop-in replacement for most S3 workloads
- **Security**: Regular updates without the concern of discontinued support
- **Community-driven**: Open-source project with transparent development

## Conclusion

Migrating from MinIO to Garage was straightforward and took less than an hour. With MinIO's shift to source-only distribution leaving many installations vulnerable, Garage provides a reliable, actively-maintained alternative that integrates seamlessly with Longhorn.

The WebUI makes management simple, and the S3 compatibility ensures that existing backup workflows continue working without modification. If you're running MinIO in a homelab environment, now is the time to consider alternatives before the next CVE drops.

## Resources

- [Garage Documentation](https://garagehq.deuxfleurs.fr/)
- [Garage WebUI Project](https://github.com/khairul169/garage-webui)
- [Longhorn Documentation](https://longhorn.io/docs/)
- [MinIO Docker Discontinuation Issue](https://github.com/minio/minio/issues/21647)