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

After three years of tinkering, upgrading, and late-night debugging sessions, here's the full tour of my homelab — from hardware to the services that keep everything running!

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

- 📱 **Phone at home** → Dell R720 fans run quieter
- 🚗 **Away from home** → Fans ramp up for better cooling

> **Pro tip:** For Dell R720 fan control details, check out my [dedicated post](http://merox.dev/blog/dell-r720/)
{: .prompt-tip }

#### Infrastructure Distribution

Each Proxmox node runs one Talos VM, ensuring:
- High availability across physical hosts
- Balanced resource utilization  
- No single point of failure for Kubernetes

The "meroxos" VM serves as my Docker escape hatch - when I need something running quickly without the overhead of Kubernetes manifests and GitOps workflows.

