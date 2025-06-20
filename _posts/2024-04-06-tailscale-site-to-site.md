---
title: Tailscale site-to-site pfSense - Linux
date: 2024-04-06 10:00:00 +0200
#categories: [Networking, VPN]
tags: [vpn, security, tutorial, tailscale, pfsense]
description: Setting up Tailscale site-to-site connection between pfSense and Linux
image:
  path: /assets/img/posts/tailscale-pfsense-banner.webp
  alt: Tailscale Site-to-Site VPN Setup
---

I've decided to implement monitoring for my homelab through a cloud virtual machine. As cloud provider I've opted for Hetzner, but more on that in a future post.

To enhance the security of this setup, I've chosen to establish the cloud VM from Hetzner as the single entry point to my infrastructure. For this purpose, I've opted to use Tailscale for tunneling, not only for client-to-site but also for site-to-site connectivity.

## Tailscale Site-to-Site Networking

Information provided by Tailscale:

> Use site-to-site layer 3 (L3) networking to connect two subnets on your Tailscale network with each other. The two subnets are each required to provide a subnet router but their devices do not need to install Tailscale. This scenario applies to Linux subnet routers only.
{: .prompt-info }

> This scenario will not work on subnets with overlapping CIDR ranges, nor with 4via6 subnet routing.
{: .prompt-warning }

## Network Architecture

In my case, there are two private subnets without any connectivity between them:

- **Subnet 1 - Homelab**: 10.57.57.0/24
- **Subnet 2 - Cloudlab**: 192.168.57.0/24

IP addresses of the routers for each subnet:
- **Subnet 1**: 10.57.57.1 (pfSense)
- **Subnet 2**: 192.168.57.254 (Linux VM)

## Setting up Tailscale on pfSense (Subnet I)

Let's dive into the configuration. Due to pfSense being based on FreeBSD and Tailscale not offering as much support for pfSense as for other platforms, this configuration is a bit trickier.

### Install Tailscale on pfSense

1. Navigate to **System > Package Manager** in the pfSense web interface
2. Click on the **Available Packages** tab
3. Search for `tailscale` and click **Install**

### Configure Tailscale on pfSense

Navigate to **VPN > Tailscale**

#### Authentication

1. Copy auth-key from [https://login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys)
2. Generate Auth keys

![Tailscale pfSense Configuration](/assets/img/posts/blog-tailscale-pfsense.png){: width="700" height="400" }
_Tailscale authentication setup in pfSense_

#### Basic Configuration

- ✅ **Enable tailscale**
- **Listen port**: leave as default
- ✅ **Accept Subnet Routes**
- ✅ **Advertise Exit Node** (optional)
- **Advertised Routes**: 10.57.57.0/24

### Tricky Part: Outbound NAT Rules

Navigate to **Firewall > NAT > Outbound**

#### Configure Outbound NAT Mode

Set to: **Hybrid Outbound NAT**

#### Create Manual Mapping

- **Interface**: Tailscale
- **Address Family**: IPv4+IPv6
- **Protocol**: Any
- **Source Network or Alias**: 10.57.57.0/24
- **Destination**: Any

> This part is broken from last update [23.09.1] so NAT Alias is missing.
{: .prompt-warning }

**Workaround**:
- Translation section:
  - **Address**: Network or Alias
  - Put the tailscale IP address: `100.xx.xx.xx/32`

This is how it should look:

![Tailscale pfSense NAT Rules](/assets/img/posts/blog-tailscale-pfsense2.png){: width="700" height="400" }
_Outbound NAT configuration for Tailscale_

## Configure Tailscale on Linux VM (Subnet II)

### Install Tailscale and Enable Routing

```bash
# Install tailscale
curl -sSL https://tailscale.com/install.sh | sh

# Activate routing for IPv4
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf

# Activate routing for IPv6
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf

# Apply routing configuration at kernel level
sudo sysctl -p /etc/sysctl.conf
```

### Advertise Routes on Linux

On the 192.168.57.254 device, advertise routes for 192.168.57.0/24:

```bash
tailscale up --advertise-routes=192.168.57.0/24 --snat-subnet-routes=false --accept-routes
```

**Command explained**:
- `--advertise-routes`: Exposes the physical subnet routes to your entire Tailscale network
- `--snat-subnet-routes=false`: Disables source NAT. In normal operations, a subnet device will see the traffic originating from the subnet router. This simplifies routing, but does not allow traversing multiple networks. By disabling source NAT, the end machine sees the LAN IP address of the originating machine as the source
- `--accept-routes`: Accepts the advertised route of the other subnet router, as well as any other nodes that are subnet routers

## Enable Subnet Routes from Admin Console

> This step is not required if using autoApprovers.
{: .prompt-info }

1. Open the **Machines** page of the admin console
2. Locate the devices configured as subnet routers (look for the **Subnets** badge or use the `property:subnet` filter)
3. For each device, click the ellipsis icon menu and select **Edit route settings**
4. In the Edit route settings panel, approve the device

> The Tailscale side of the routing is complete!
{: .prompt-tip }

## Credits

- [Tailscale Documentation](https://tailscale.com/kb/1214/site-to-site#step-2-enable-subnet-routes-from-the-admin-console) - Official site-to-site networking guide
- [Christian McDonald](https://www.youtube.com/watch?v=Fg_jIPVcioY) - Helpful YouTube tutorial on pfSense Tailscale setup