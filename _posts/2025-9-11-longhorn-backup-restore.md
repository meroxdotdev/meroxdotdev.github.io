---
title: "Restoring from Longhorn Backups"
date: 2025-09-11 14:30:00 +0300
categories: [infrastructure]
#tags: [kubernetes,longhorn,backup,restore,disaster-recovery,k8s,storage,minio,prometheus,grafana,jellyfin,flux,gitops]
description: Oops, My App Died! The Complete Human's Guide to Rescuing Kubernetes Applications from Longhorn Backups in MinIO
image:
  path: /assets/img/posts/k8s-longhorn-restore.webp
  alt: Kubernetes Longhorn backup restoration guide
draft: false
---


# Restoring Your Kubernetes Applications from Longhorn Backups

When disaster strikes your Kubernetes cluster, having a solid backup strategy isn't enough—you need to know how to restore your applications quickly and reliably. Recently, I had to rebuild my entire K8S cluster from scratch and restore all my applications from Longhorn backups stored in MinIO. Here's the complete process that got my media stack and observability tools back online.

## The Situation

After redeploying my K8S cluster with [Flux GitOps](https://merox.dev/blog/homelab-tour/), I found myself with:
- ✅ Fresh cluster with all applications deployed via Flux
- ✅ Longhorn storage configured and connected to MinIO backend
- ✅ All backup data visible in Longhorn UI
- ❌ Empty volumes for all applications
- ❌ Lost configurations, dashboards, and media metadata

The challenge? Restore 6 critical applications to their backup state without losing the current Flux-managed infrastructure.

## Applications to Restore

Here's what needed restoration:
- **Prometheus** (45GB) - Monitoring metrics and configuration
- **Loki** (20GB) - Log aggregation and retention
- **Jellyfin** (10GB) - Media library and metadata
- **Grafana** (10GB) - Dashboards and data sources
- **QBittorrent** (5GB) - Torrent client configuration
- **Sonarr** (5GB) - TV show management settings

## Prerequisites

Before starting, ensure you have:
- Kubernetes cluster with kubectl access
- Longhorn installed and configured
- Backup storage backend accessible (MinIO/S3)
- Applications deployed (scaled up or down doesn't really matter)
- Longhorn UI access for backup management

## Step 1: Assess Current State

First, let's understand what we're working with:

```bash
# Check current deployments and statefulsets
kubectl get deployments -A
kubectl get statefulsets -A

# Review current PVCs
kubectl get pvc -A -o wide

# Verify Longhorn storage class
kubectl get storageclass
```

This gives you a complete picture of your current infrastructure and identifies which PVCs need replacement.

## Step 2: Scale Down Applications

**Critical:** Before touching any storage, scale down applications to prevent data corruption:

```bash
# Scale down deployments
kubectl scale deployment jellyfin --replicas=0 -n default
kubectl scale deployment qbittorrent --replicas=0 -n default
kubectl scale deployment sonarr --replicas=0 -n default
kubectl scale deployment grafana --replicas=0 -n observability

# Scale down statefulsets
kubectl scale statefulset loki --replicas=0 -n observability
kubectl scale statefulset prometheus-kube-prometheus-stack --replicas=0 -n observability
kubectl scale statefulset alertmanager-kube-prometheus-stack --replicas=0 -n observability
```

Wait for all pods to terminate before proceeding.

## Step 3: Remove Current Empty PVCs

Since the current PVCs contain only empty data, we need to remove them:

```bash
# Delete PVCs in default namespace
kubectl delete pvc jellyfin -n default
kubectl delete pvc qbittorrent -n default
kubectl delete pvc sonarr -n default

# Delete PVCs in observability namespace
kubectl delete pvc grafana -n observability
kubectl delete pvc storage-loki-0 -n observability
kubectl delete pvc prometheus-kube-prometheus-stack-db-prometheus-kube-prometheus-stack-0 -n observability
```

## Step 4: Restore Backups via Longhorn UI

This is where the magic happens. Access your Longhorn UI and navigate to the **Backup** tab.

For each backup, click the **⟲ (restore)** button and configure:

### Prometheus Backup
- **Name**: `prometheus-restored`
- **Storage Class**: `longhorn`
- **Access Mode**: `ReadWriteOnce`

### Loki Backup
- **Name**: `loki-restored`
- **Storage Class**: `longhorn`
- **Access Mode**: `ReadWriteOnce`

### Jellyfin Backup
- **Name**: `jellyfin-restored`
- **Storage Class**: `longhorn`
- **Access Mode**: `ReadWriteOnce`

### Continue for all other backups...

**Important**: Wait for all restore operations to complete before proceeding. You can monitor progress in the Longhorn UI.

## Step 5: Create PersistentVolumes

Once restoration completes, the restored Longhorn volumes need PersistentVolumes to be accessible by Kubernetes:

```yaml
# Example for Jellyfin - repeat for all applications you want to be restored
apiVersion: v1
kind: PersistentVolume
metadata:
  name: jellyfin-restored-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: longhorn
  csi:
    driver: driver.longhorn.io
    fsType: ext4
    volumeAttributes:
      numberOfReplicas: "3"
      staleReplicaTimeout: "30"
    volumeHandle: jellyfin-restored
```

Apply this pattern for all restored volumes, adjusting the `storage` capacity and `volumeHandle` to match your backups.

## Step 6: Create PersistentVolumeClaims

Now create PVCs that bind to the restored PersistentVolumes:

```yaml
# Example for Jellyfin
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jellyfin
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: longhorn
  volumeName: jellyfin-restored-pv
```

The key here is using `volumeName` to bind the PVC to the specific PV we created.

## Step 7: Verify Binding

Check that all PVCs are properly bound:

```bash
# Check binding status
kubectl get pvc -n default | grep -E "(jellyfin|qbittorrent|sonarr)"
kubectl get pvc -n observability | grep -E "(grafana|storage-loki|prometheus)"

# Verify Longhorn volume status
kubectl get volumes -n longhorn-system | grep "restored"
```

You should see all PVCs in `Bound` status and Longhorn volumes as `attached` and `healthy`.

## Step 8: Scale Applications Back Up

With storage properly restored and connected, bring your applications back online:

```bash
# Scale deployments back up
kubectl scale deployment jellyfin --replicas=1 -n default
kubectl scale deployment qbittorrent --replicas=1 -n default
kubectl scale deployment sonarr --replicas=1 -n default
kubectl scale deployment grafana --replicas=1 -n observability

# Scale statefulsets back up
kubectl scale statefulset loki --replicas=1 -n observability
kubectl scale statefulset prometheus-kube-prometheus-stack --replicas=1 -n observability
kubectl scale statefulset alertmanager-kube-prometheus-stack --replicas=1 -n observability
```

## Step 9: Final Verification

Confirm everything is working correctly:

```bash
# Check pod status
kubectl get pods -A | grep -v Running | grep -v Completed

# Verify Longhorn volumes are healthy
kubectl get volumes -n longhorn-system | grep "restored"

# Test application functionality
kubectl get pods -n default -o wide
kubectl get pods -n observability -o wide
```


## Alternative: CLI-Based Restoration

For automation or when UI access isn't available, you can restore via Longhorn's CRD:

```yaml
apiVersion: longhorn.io/v1beta1
kind: Volume
metadata:
  name: jellyfin-restored
  namespace: longhorn-system
spec:
  size: "10737418240"  # Size in bytes
  restoreVolumeRecurringJob: false
  fromBackup: "s3://your-minio-bucket/backups/backup-name"
```

## Conclusion

Restoring Kubernetes applications from Longhorn backups requires careful orchestration of scaling, PVC management, and volume binding. The process took about 30 minutes for 6 applications, but the result was a complete restoration to the previous backup state.

Having a solid backup strategy is crucial, but knowing how to restore efficiently under pressure is what separates good infrastructure management from great infrastructure management.


Your future self will thank you when disaster strikes again. 😆