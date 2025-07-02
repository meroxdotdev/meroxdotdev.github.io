---
title: "Complete Homelab Tour 2025"
date: 2025-06-23 10:00:00 +0300
categories: [infrastructure]
tags: [homelab,kubernetes,automation,flux,talos,k8s]
description: Finally, after 3 years as homelabber, this is my complete tour of my hardware and services which run inside my homelab, hope you will enjoy it!
image:
  path: /assets/img/posts/homelab.webp
  alt: Complete homelab tour
---


![My homelab rack setup](/assets/img/posts/homelab.jpg)

##  Hardware Overview

### Power Protection

| Device | Model | Protected Equipment | Capacity |
|:-------|:------|:-------------------|:---------|
| **UPS #1** | CyberPower | Dell R720 | 1500VA |
| **UPS #2** | CyberPower | Mini PCs + Network | 1000VA |

### Network Stack

| Device | Model | Specs | Purpose |
|:-------|:------|:------|:--------|
| **ONT** | Huawei | 1GbE | ISP Gateway |
| **Firewall** | XCY X44 | 8× 1GbE | pfSense Router |
| **WiFi** | TP-Link AX3000 | WiFi 6 | Wireless AP |
| **Switch** | TP-Link | 24-port | Core Switch |

### Compute Resources

> **On-Premise Hardware**
{: .prompt-info }

| Device | CPU | RAM | Storage | Purpose |
|:-------|:----|:----|:--------|:--------|
| **Beelink GTi 13** | i9-13900H (14C/20T) | 64GB DDR5 | 2× 2TB NVMe | Proxmox |
| **OptiPlex #1** | i5-6500T (4C/4T) | 16GB DDR4 | 128 GB NVME / 2TB | Proxmox |
| **OptiPlex #2** | i5-6500T (4C/4T) | 16GB DDR4 | 128 GB NVME / 2TB | Proxmox |
| **Dell R720** | 2× E5-2697v2 (24C/48T) | 192GB ECC | 4× 960GB SSD | Backup Server |
| **Synology DS223+** | ARM RTD1619B | 2GB | 2× 2TB RAID1 | NAS/Media |

> **Cloud Infrastructure**
{: .prompt-tip }

| Provider | Instance | Specs | Location | Purpose |
|:---------|:---------|:------|:---------|:--------|
| **Hetzner** | CX32 | 4vCPU/8GB/80GB | 🇩🇪 Germany | Off-site Backup |
| **Oracle** | Ampere A1 | 4vCPU/24GB/200GB | 🇺🇸 USA | Docker Test |


##  Network Architecture

### Simple but Effective Design

I've kept my network intentionally simple - no VLANs or complex routing (yet). Three dedicated physical interfaces on pfSense handle everything:

```
WAN Interface → Orange ISP (Bridge Mode)
LAN Interface → Homelab Network
WiFi Interface → Guest/IoT Isolation
```

> **Security Note:** WiFi clients are firewalled from homelab services, except whitelisted ones like Jellyfin
{: .prompt-warning }

### Network Topology

![Homelab Network Topology Diagram](/assets/img/posts/network.draw.svg)
*Click to enlarge - Full network topology including Tailscale mesh connections*

> **Geo-distributed Exit Nodes:** Both VPS instances double as Tailscale exit nodes, allowing me to route traffic through EU (Hetzner) or US (Oracle) regions for geo-restricted content or better latency.


## Selfhosted Apps

### pfSense


The heart of my network - a fanless mini PC from AliExpress (~100€) running pfSense for 3+ years:

👉 [XCY X44 on AliExpress](https://www.aliexpress.com/item/1005004848317962.html)

![pfSense services dashboard](/assets/img/posts/pfsense-services.png)


#### Tailscale Subnet Router
Exposes the entire homelab to cloud VPS without installing Tailscale on every device. Perfect solution for CGNAT bypass.

[Setup guide →](https://merox.dev/blog/tailscale-site-to-site/)

#### Unbound DNS
Local recursive resolver with domain overrides for `*.k8s.merox.dev` pointing to K8s-Gateway.

#### Telegraf
Pushes system metrics to Grafana for monitoring dashboards.

#### Network Security
- **WiFi → LAN**: Block all except some self-hosted apps
- **LAN → WAN**: Allow all  
- **WAN → Internal**: Block all except exposed services


### UPS #2

Managing power for the critical infrastructure - the CyberPower 1000VA protects all mini PCs and network equipment:

#### Power Management Features

| Feature | Implementation | Purpose |
|:--------|:---------------|:--------|
| **pwrstat** | USB to GTi13 Pro | Automated shutdown orchestration |
| **SSH Scripts** | Custom automation | Graceful cluster shutdown |
| **Monitoring** | Telegram alerts | Real-time power notifications |

![UPS monitoring dashboard](/assets/img/posts/ups.png)

> **Safety First:** When power fails, the UPS triggers a cascading shutdown sequence - K8s nodes drain properly before Proxmox hosts power down
{: .prompt-warning }

#### Telegram Integration

Instant notifications keep me informed of power events wherever I am:

![Telegram UPS notification](/assets/img/posts/telegram-notif1.jpeg)

### Synology DS223+

The reliable storage backbone - serving dual purposes in my infrastructure:

#### Media Storage
- **Protocol**: SMB/NFS shares (experimenting with both)
- **Purpose**: Central storage for ARR stack
- **Access**: Mounted directly in K8s pods and Docker containers

#### Personal Cloud
After 3 years of self-hosting Nextcloud, I switched to Synology Drive for a more polished experience:

- ✅ **Better performance** than my Nextcloud instance
- ✅ **Native mobile apps** that actually work reliably
- ✅ **Set-and-forget** reliability for family photos/documents
- ✅ **2TB RAID1** protection for peace of mind

![Synology services overview](/assets/img/posts/synology.png)

> **Experience Note:** Sometimes the best self-hosted solution is the one that requires the least maintenance. Synology Drive has been that for my personal files.
{: .prompt-info }

### Test Enterprise Server (Dell R720)

The power-hungry beast of the homelab - this old datacenter workhorse has served many purposes over the past year:

#### Evolution of Use Cases

| Period | Purpose | Configuration | Notes |
|:-------|:--------|:--------------|:------|
| **Phase 1** | Proxmox hypervisor | 24C/48T, 192GB RAM | Raw performance testing |
| **Phase 2** | AI Playground | Quadro P2200 GPU | Ollama + Open WebUI |
| **Current** | Backup Target | 4× 960GB RAID-Z2 | Weekly MinIO sync |

#### Hardware Modifications

The most interesting project was **flashing the RAID controller to IT mode** - completely bypassing hardware RAID for direct disk access:

> **Guide:** For H710/H310 crossflashing instructions, check out [Fohdeesha's excellent guide](https://fohdeesha.com/docs/perc.html)
{: .prompt-tip }

#### Remote Management

iDRAC Enterprise makes this server a joy to manage remotely:

![iDRAC management interface](/assets/img/posts/idrac-dellr720.png)

#### Current Role: Off-site Backup Target

Given the ~200W idle power consumption, I've implemented a smart scheduling system:

-  **Power Schedule**: Wake-on-LAN 1-2× weekly
-  **Sync Task**: Pull MinIO backups from Hetzner VPS
-  **Storage**: RAID-Z2 for redundancy
-  **3-2-1 Rule**: Completes my backup strategy

> **Power Efficiency Note:** Running 24/7 would cost ~€20/month in electricity.
{: .prompt-warning }

*Still constantly changing my mind about what to run here*


### Proxmox

The compute playground of my homelab - a small but mighty 3-node cluster spread across my mini PCs.

![Proxmox cluster overview](/assets/img/posts/proxmox.png)

> **Philosophy Change:** I've simplified from my previous complex setup. Rather than managing dozens of VMs/containers, I now focus on quality over quantity - running only what truly adds value.
{: .prompt-info }

#### Current Virtual Machines

| VM | Purpose | Specs | Notes |
|:---|:--------|:------|:------|
| **3× Talos K8s** | Kubernetes nodes | 4vCPU/16GB/1TB | Intel iGPU passthrough |
| **meroxos** | Docker playground | 4vCPU/8GB/500GB | K8s alternative for simpler services |
| **Windows Server 2019** | AD Lab | 4vCPU/8GB/100GB | Active Directory experiments |
| **Windows 11** | Remote desktop | 4vCPU/8GB/50GB | Always-ready Windows machine |
| **Home Assistant** | Home automation | 2vCPU/4GB/32GB | See automation section below |
| **Kali Linux** | Security testing | 2vCPU/4GB/50GB | *To be restored from PBS* |
| **GNS3** | Network lab | 4vCPU/8GB/100GB | *To be restored from PBS* |

#### Smart Home Integration

While I have various IoT devices, my Home Assistant setup is intentionally minimal. The most interesting automation? **Location-based server fan control**:

-  **Phone at home** → Dell R720 fans run quieter
-  **Away from home** → Fans ramp up for better cooling

> **Pro tip:** For Dell R720 fan control details, check out my [dedicated post](http://merox.dev/blog/dell-r720/)
{: .prompt-tip }

#### Infrastructure Distribution

Each Proxmox node runs one Talos VM, ensuring:
- High availability across physical hosts
- Balanced resource utilization  
- No single point of failure for Kubernetes


### Cloud Machines

Extending beyond the homelab walls - strategic cloud deployments for resilience and global reach:

![Hetzner cloud dashboard](/assets/img/posts/hetzner.png)

#### Infrastructure Overview

All managed through a single Portainer instance at `cloud.merox.dev`:

![Portainer multi-cluster view](/assets/img/posts/clusters.png)

> **Cost Optimization:** Hetzner's CX32 at ~€8/month provides the perfect balance of resources for 24/7 operations
{: .prompt-tip }

#### cloud-de (Hetzner VPS)

The always-on sentinel watching over my homelab:

| Service | Container | Purpose |
|:--------|:----------|:--------|
| **Monitoring Stack** | Grafana, Prometheus, Alertmanager | External homelab monitoring |
| **Pi-hole** | DNS resolver | Dedicated Tailscale split-DNS |
| **Traefik** | Reverse proxy | SSL certificates for all VPS services |
| **Guacamole** | Remote access | Cloudflare Tunnel exposed |
| **Firefox** | Browser container | GUI access via Guacamole RDP |

> **Reliability First:** When the homelab is down, this VPS ensures I can still access critical services and troubleshoot remotely
{: .prompt-warning }

#### homelab-ro (Local Docker)

The emergency escape hatch - when Kubernetes complexity becomes too much:

| Service | Purpose | Note |
|:--------|:--------|:-----|
| **ARR Stack** | Media automation | Quick restore when K8s fails |
| **Netboot.xyz** | PXE server | Network boot any OS/tools |
| **Portainer Agent** | Management | Remote Docker control |

*Because sometimes you just need things to work without debugging YAML manifests at 2 AM*

#### cloud-usa (Oracle Free Tier)

The wildcard instance leveraging Oracle's generous free tier:

- **Testing ground** for experimental Docker images
- **Tailscale exit node** for US geo-location
- **Not in Portainer** - hit the 5-node limit (3× K8s + 2× Docker)

> **Free Tier Limits:** Portainer BE restricts to 5 nodes. Priority given to production workloads over test instances.
{: .prompt-info }

#### k8s (Kubernetes Cluster)

*My guilty pleasure* - because who doesn't love over-engineering their homelab?

- **Portainer integration** for centralized overview
- **Quick health checks** without kubectl
- **Detailed coverage** in the dedicated K8s section below

> **Architecture Note:** Each cloud instance serves as a Tailscale subnet router, creating a global mesh network with automatic failover capabilities
{: .prompt-tip }

### Talos & Kubernetes

- CI/CD based on onedr0p/cluster-template:
  - https://github.com/meroxdotdev/infrastructure 
  - specific added for my usecase:
    - longhorn (with MinIO backup on Hetzner VPS & Storagebox)
    - grafana & kube-prometetheus stack
    - Arr stack ( analog to meroxos VM)
    - dashboard homepage
