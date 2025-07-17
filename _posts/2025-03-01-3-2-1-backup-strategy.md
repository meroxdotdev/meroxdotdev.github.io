---
title: "Disaster Recovery: Safeguarding My Critical Data"
date: 2025-03-01 10:00:00 +0200
categories: [infrastructure]
tags: [homelab, backup, disaster-recovery, proxmox, synology, hetzner, pbs, security]
description: A structured disaster recovery plan for homelab enthusiasts and businesses.
image:
  path: /assets/img/posts/disaster-recovery-banner.webp
  alt: Disaster Recovery Guide for Homelab and Business
---

In today's digital landscape, data loss can be catastrophic whether you're running a sophisticated homelab or managing IT for an organization of any size. This guide shares my personal disaster recovery strategy, incorporating industry best practices and security considerations to help you build resilience against potential failures.

## Common Backup Mistakes and Ransomware Risks

> Even with a structured backup plan, common mistakes can make backups ineffective when disaster strikes.
{: .prompt-warning }

### ❌ Frequent Backup Mistakes

- **Lack of Backup Testing** – A backup is useless if you've never tested restoring from it.
- **Storing Backups on the Same System** – Backups stored on the same machine or network are vulnerable to failures, ransomware, and accidental deletion.
- **Unencrypted Backups** – Without encryption, your backups can be easily compromised.
- **Overwriting Previous Backups** – Without versioning, ransomware or file corruption can render all backup copies useless.
- **No Offsite Backup** – Only keeping local copies increases risk in case of fire, theft, or natural disasters.

### 🔥 Ransomware & Backup Protection

> Modern ransomware attacks actively seek and encrypt backup files, making recovery impossible unless preventive measures are in place.
{: .prompt-danger }

To mitigate these threats:

- **🛡 Implement Backup Protections**
    - PBS allows **marking snapshots as 'protected'**, preventing accidental deletion.  
    - **Note:** Users with sufficient permissions can still remove this protection.  
    - More details: [Proxmox Forum Discussion](https://forum.proxmox.com/threads/immutable-backups.107332/)
- **🔌 Air-Gapped Backups** – Maintain at least one backup that is offline or isolated from the network.
- **🔑 Enable Multi-Factor Authentication (MFA)** – Restrict access to backup systems to prevent unauthorized tampering.
- **📊 Set Up Alerts for Backup Failures** – Ensure you're notified immediately when a backup job fails, so you can take action.

> By addressing these risks, you can ensure your backups remain resilient against both accidental failures and cyber threats.
{: .prompt-tip }

## My Infrastructure Stack

### Core Components

- **Primary Storage**: Synology DS223 with 2x2TB drives in RAID1 configuration

![Synology NAS](/assets/img/posts/disaster-recovery-synology.png){: width="600" height="400" }
_Synology DS223 NAS setup_

- **Backup Server**: Proxmox Backup Server (PBS) running with 4x Intel D3-S4510 SSDs in RAIDz2

![Proxmox Backup Server](/assets/img/posts/disaster-recovery-pbs.png){: width="600" height="400" }
_Proxmox Backup Server configuration_

- **Offsite Storage**: Hetzner VPS with attached StorageBox for geographical redundancy

![Hetzner Storage Box](/assets/img/posts/disaster-recovery-hetzner.png){: width="600" height="400" }
_Hetzner StorageBox setup_

- **Secure Key Management**: Local KeyPass on iOS/MacOS containing encryption keys

### The 3-2-1 Backup Strategy in Action

I've implemented the widely-recommended 3-2-1 backup approach:
- **3** copies of data (original + 2 backups)
- **2** different storage types (local NAS and cloud storage)
- **1** offsite copy (Hetzner StorageBox)

### Backup Flow & Schedule

My automated backup chain ensures data flows through the system with minimal intervention:

1. **VM/LXC → PBS**: Every Saturday at 02:00
   - Primary backup of all virtual machines and containers
   - Encrypted at rest for security

![Proxmox Backup Schedule](/assets/img/posts/disaster-recovery-schedule.png){: width="700" height="400" }
_Automated backup schedule configuration_

2. **PBS → Synology**: Every Saturday at 06:00
   - Secondary local copy using rsync and crontab
   - RAID1 protection against single drive failure

3. **Synology → Hetzner**: Every Saturday at 08:00
   - Offsite copy for geographic redundancy
   - Protection against local disasters (fire, theft, etc.)

## Implementation Details

### Critical Scripts for Backup Automation

#### PBS to Synology Rsync (Running on PBS Server)

```bash
0 6 * * 6 rsync -av --delete --progress /mnt/datastore/ /mnt/hyperbackup/ >> /var/log/rsync_backup.log 2>&1
```

More info about these scripts can be found [here](#scenario-2-hetzner-vpsstoragebox-failure)

#### Proxmox Backup Client Script (backup-pbs.sh)

```bash
#!/bin/bash

# 1) Export token secret as "PBS_PASSWORD"
export PBS_PASSWORD='token-secret-from-PBS'

# 2) Define user@pbs + token
export PBS_USER_STRING='token-id-from-PBS'

# 3) PBS IP/hostname
export PBS_SERVER='PBS-IP'

# 4) Datastore name
export PBS_DATASTORE='DATASTORE_PBS'

# 5) Build complete repository
export PBS_REPOSITORY="${PBS_USER_STRING}@${PBS_SERVER}:${PBS_DATASTORE}"

# 6) Get local server shortname
export PBS_HOSTNAME="$(hostname -s)"

# 7) ENCRYPTION KEY
export PBS_KEYFILE='/root/pbscloud_key.json'

echo "Run pbs backup for $PBS_HOSTNAME ..."

proxmox-backup-client backup \
  srv.pxar:/srv \
  volumes.pxar:/var/lib/docker/volumes \
  netw.pxar:/var/lib/docker/network \
  etc.pxar:/etc \
  scripts.pxar:/usr/local/bin \
  --keyfile /root/pbscloud_key.json \
  --skip-lost-and-found \
  --repository "$PBS_REPOSITORY"

# List existing backups
proxmox-backup-client list --repository "${PBS_REPOSITORY}"

echo "Done."
```

#### Proxmox Backup Client Restore Script (backup-pbs-restore.sh)

```bash
#!/bin/bash

# Global configs
export PBS_PASSWORD='token-secret-from-PBS'
export PBS_USER_STRING='token-id-from-PBS'
export PBS_SERVER='PBS_IP'
export PBS_DATASTORE='DATASTORE_FROM_PBS'
export PBS_KEYFILE='/root/pbscloud_key.json'
export PBS_REPOSITORY="${PBS_USER_STRING}@${PBS_SERVER}:${PBS_DATASTORE}"

# Input parameters
SNAPSHOT_PATH="$1"
ARCHIVE_NAME="$2"
RESTORE_DEST="$3"

# Parameter validation
if [[ -z "$SNAPSHOT_PATH" || -z "$ARCHIVE_NAME" || -z "$RESTORE_DEST" ]]; then
  echo "Usage: $0 <snapshot_path> <archive_name> <destination>"
  echo "Example: $0 \"host/cloud/2025-01-22T15:19:17Z\" srv.pxar /root/restore-srv"
  exit 1
fi

# Create destination if needed
mkdir -p "$RESTORE_DEST"

# Summary display
echo "=== PBS Restore ==="
echo "Snapshot:      $SNAPSHOT_PATH"
echo "Archive:       $ARCHIVE_NAME"
echo "Destination:   $RESTORE_DEST"
echo "Repository:    $PBS_REPOSITORY"
echo "Encryption key $PBS_KEYFILE"
echo "====================="

# Run restore
proxmox-backup-client restore \
  "$SNAPSHOT_PATH" \
  "$ARCHIVE_NAME" \
  "$RESTORE_DEST" \
  --repository "$PBS_REPOSITORY" \
  --keyfile "$PBS_KEYFILE"

EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
  echo "=== Restore completed successfully! ==="
else
  echo "Restore error (code $EXIT_CODE)."
fi

exit $EXIT_CODE
```

## Disaster Recovery Scenarios

Having a backup is only half the solution—knowing how to restore is equally critical. Here are my documented procedures for various failure scenarios:

### Scenario 1: Synology NAS Failure

Even if my primary NAS fails, data remains safe in two locations:
1. Proxmox Backup Server (4x Intel SSDs in RAIDz2)
2. Hetzner StorageBox (offsite)

**Recovery Steps:**
1. Replace the failed hardware components
2. Reconfigure RAID1 on the new or repaired NAS
3. Restore HyperBackup schedule (targeting Saturday 08:00)
4. Verify successful completion of first backup cycle

### Scenario 2: Hetzner VPS/StorageBox Failure

If my cloud provider experiences issues:

1. Provision a new VPS with appropriate specifications
2. Install proxmox-backup-client:
   - For Ubuntu: Follow the [community guide](https://forum.proxmox.com/threads/install-the-backup-client-on-ubuntu-desktop-24-04.146065/)
   - For Debian: Use standard package installation methods
3. Create the encryption key file at `/root/pbscloud_key.json`:
   - Retrieve the key from KeyPass (stored on iOS/MacOS)
4. Deploy backup automation scripts:
   - `backup-pbs.sh` for regular backups
   - `backup-pbs-restore.sh` for potential recoveries
5. Test both backup and restore functionality to verify operations
6. Restore crontab for automatically backup:

```bash
0 2 * * * /usr/local/bin/backup-pbs.sh >> /var/log/backup-cloud.log 2>&1
```

### Scenario 3: PBS Server Failure

In case my primary backup server fails:

1. Download and install the latest PBS ISO
2. Configure storage properly:

```bash
# /etc/proxmox-backup/datastore.cfg
datastore: raidz2
        comment
        gc-schedule sat 03:30
        notification-mode notification-system
        path /mnt/datastore
```

3. Verify `/etc/fstab` contains correct mount point:

```bash
#raidz2
/dev/sdb /mnt/datastore ext4 defaults 0 2
```

> **Note**: /dev/sdb represents the RAIDz2 array (because in this scenario the PBS is a VM and /dev/sdb is a second disk attached from RAIDz2 pool)
{: .prompt-info }

4. Ensure the datastore has the required structure:
   - `.chunks`
   - `vm`
   - `.gc-status`
   - `ct`
   - `host`

5. Data can be restored from multiple sources:
   - Original RAIDz2 array (if drives survived)
   - Hetzner StorageBox (`/mnt/storagebox/Storage_1`)
   - Synology NAS (`/volume1/Backup/Proxmox/hyperbackup`)

6. Import VM/LXC encryption key from KeyPass into the new PVE environment.

## Security Best Practices

Based on my experience, here are critical security measures for robust disaster recovery:

### Encryption Throughout the Chain

1. **Data-at-Rest Encryption**: All my backups are encrypted using strong keys
2. **Transport Encryption**: Using secure SSH tunnels for data transfer
3. **Key Management**: Isolated storage of encryption keys in KeyPass
4. **Regular Key Rotation**: Changing encryption keys periodically

### Access Control

1. **Principle of Least Privilege**: Backup systems have minimal permissions
2. **Token-Based Authentication**: Using secure tokens rather than passwords
3. **Network Segmentation**: Backup systems on separate network segments
4. **Firewall Rules**: Strict ingress/egress rules for backup traffic

### Critical Files and Keys

Always securely store:
- Encryption keys in KeyPass (iOS/MacOS):
  - `/root/pbscloud_key.json`
  - PBS VM/LXC encryption key
- PBS Configuration: `/etc/proxmox-backup/datastore.cfg`
- Backup location references:
  1. PBS: `/mnt/datastore`
  2. Synology: `/volume1/Backup/Proxmox/hyperbackup`
  3. Hetzner: `/mnt/storagebox/Storage_1`

## Continuous Improvement Recommendations

> No backup system is perfect without ongoing validation and improvement. Here are practices I'm implementing or planning to adopt:
{: .prompt-tip }

### ✅ Regular Backup Verification
- **🔄 Monthly integrity checks** on random files  
- **🔍 Checksum validation** to detect bit rot  
- **📊 Log analysis** for backup completion and failures  

### 🛠 Automated Recovery Testing
- **🔄 Quarterly test restores** to verify recoverability  
- **📜 Documented results** with timing measurements  
- **🎯 Improvement targets** based on test results  

### 🔔 Monitoring and Alerting
- **📡 Real-time monitoring** of backup processes  
- **⚠ Alert systems** for backup failures or delays  
- **📉 Storage capacity trend analysis** to prevent space issues  

### 📖 Documentation and Training
- **📑 Keeping recovery documentation updated**  
- **🔄 Regular practice** of recovery procedures  
- **👥 Cross-training** to ensure multiple people can perform recovery  

### 🔐 Security Updates
- **🔄 Regular patching** of backup systems  
- **🛡 Vulnerability scanning** of the backup infrastructure  
- **🔑 Updating encryption standards** as needed  

## Conclusion

> Disaster recovery isn't just about having backups—it's about having a **proven, tested strategy** that can be executed confidently when needed.
{: .prompt-tip }

For **homelabbers and businesses alike**, the approach outlined here provides a **solid foundation** for data protection **without enterprise-level budgets**.  

By implementing **proper backup chains, documenting recovery procedures, and regularly testing your systems**, you can achieve **peace of mind** knowing your critical data can survive:  
✔ Hardware failures  
✔ Human errors  
✔ Malicious attacks  

**💬 What disaster recovery strategies do you use in your environment?**  
I'd love to hear your thoughts and experiences in the comments below! 🚀

---

*Disclaimer: This approach works for my specific needs but should be adapted to your unique requirements. Always test your recovery procedures thoroughly before relying on them in an actual disaster scenario.*