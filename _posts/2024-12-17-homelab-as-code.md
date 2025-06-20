---
title: "Homelab as Code: Packer + Terraform + Ansible"
date: 2024-12-17 10:00:00 +0200
categories: [infrastructure, devops]
tags: [automation, terraform, ansible, homelab, packer, proxmox, docker]
description: Step-by-step guide to building and automating your homelab, from the ground up. Discover why a homelab is a must-have for mastering IT skills in server management, networking, and automation.
image:
  path: /assets/img/posts/featured-homelabascode.webp
  alt: Homelab as Code with Packer, Terraform and Ansible
---

Managing a homelab can feel like navigating a maze of configurations, updates, and potential errors. **But what if you could rebuild your entire setup in minutes**? This blog introduces a solution that not only streamlines your homelab into an automated environment but also provides a learning experience, helping you better understand server management, automation, and networking.

## Real Scenarios

Here are some practical examples of what you can achieve with this setup:

- **Jellyfin Streaming**: Imagine accessing your entire media library securely via Jellyfin, pre-configured with SSL, directly accessible from anywhere.
- **Proxmox Management**: Manage your Proxmox dashboard securely using a custom domain like `proxmox.yourdomain.com`, with SSL automatically handled by Traefik.
- **Docker Management**: Quickly deploy and manage all your containers in Portainer, accessible at `portainer.yourdomain.com`.

## Requirements

> This project will **deploy Ubuntu Virtual Machine** packed with commonly self-hosted tools like Docker, Portainer, Media Stack, Traefik, and more. Here's what you'll need:
> 
> 1. **Proxmox VE**: For creating and managing the VM.
> 2. **Fresh LXC**: Required to run the script mentioned below.
> 3. **DNS Server**: A properly configured DNS setup for service domains.
> 4. **Essentials**: A few beers to keep the spirits high! 🍻
{: .prompt-info }

> This guide is designed to document my homelab automation process, but it's flexible enough to help anyone looking to simplify their IT environment. **Let's get started!**
{: .prompt-tip }

## Resources

**📊 Architecture Diagram**: A high-level diagram of what we will implement in this blog

![Homelab Architecture Diagram](/assets/img/posts/diagram.svg){: width="700" height="400" }
_Homelab automation architecture overview_

**💻 Source Code**: [meroxdotdev/homelab-as-code](https://github.com/meroxdotdev/homelab-as-code)

## What's Inside the Repository?

This repository simplifies homelab deployment with everything needed to set up an VM and associated services.

- **Interactive Deployment Script**:
  - Installs required packages (`git`, `curl`, `ansible`, `packer`, `terraform`).
  - Clones the repository (supports both public and private setups).
  - Runs Packer, Terraform and Ansible for fully automated deployment.

- **Configuration Folders**:
  - **`ansible`**: Includes roles for deploying Docker, Portainer, Traefik, and optional NFS mounts.
  - **`configs/docker`**: Pre-configured services like getHomepage, Traefik, and media stack.
  - **`packer`**: Builds an optimized Ubuntu template for Proxmox, ready for Terraform deployments.
  - **`terraform`**: Automates VM creation with networking and storage configurations based on packer template.

## Quick Start

Execute the following command:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/meroxdotdev/homelab-as-code/refs/heads/master/deploy_homelab.sh)"
```

> **Tip**: Run this script on a clean **LXC** for best results.
{: .prompt-tip }

### Deployment Process

1. **Initial Prompts**  
   - First, the script will ask for the repository type (**public** or **private**).  
     - For a private repository, ensure you provide the SSH link (e.g., `git@github.com:meroxdotdev/homelab.git`) instead of HTTPS.
     - For a public repository, you can directly use this one tutorial-based: `https://github.com/meroxdotdev/homelab-as-code.git`
   - If private is selected, the script generates an SSH key and prompts you to add the public key to your repository under **Settings → Deploy Keys** (e.g., in GitHub).

   ![Initial Prompt](/assets/img/posts/homelab-initial-prompt.png){: width="600" height="300" }

2. **Confirmation Prompt**  
   - Next, the script asks if you've edited the necessary files for deployment.
   - Type **yes** to proceed with the Packer, Terraform and Ansible automation.
   - If you type **no**, review the blog for guidance on editing the required files, then re-run the script after making changes.
   
   ![Edit Confirmation Prompt](/assets/img/posts/homelab-confirmation-prompt.png){: width="600" height="300" }
   
   - **Resources**: You will find the downloaded configuration in `/home/homelab/`

## Ansible Configuration

### Inventory Folder

The `inventory` folder is essential for Terraform and Ansible integration, as it holds the dynamically generated `inventory.ini` file. This file maps the VM IP address and SSH credentials for Ansible to use.

Here's how it's created in the Terraform configuration:

```terraform
resource "local_file" "ansible_inventory" {
  depends_on = [time_sleep.wait_1_minute]

  content = <<EOT
[docker]
docker-01 ansible_host=IP_DEPLOYMENT ansible_user=root ansible_ssh_private_key_file=~/.ssh/id_rsa
EOT

  filename = "../ansible/inventory/inventory.ini"
}
```

You don't need to edit anything in this folder manually, as it is automatically generated during deployment.

### Roles Folder

The `roles/docker` folder contains all the necessary playbooks for setting up:
- **Docker**
- **Docker Compose**
- **Portainer**
- **getHomepage**
- **Traefik**

Each service has a specific `.yml` file that automates its installation and configuration.

### Configuring NFS Mount (Optional)

If you plan to use an external NFS share, update the `roles/nfs_mount` file with your specific configuration:

**Step 1**: Replace the placeholder with your NFS server's IP or FQDN:
```bash
REPLACE_this_with_your_nfs_server_ip_address
```

**Step 2**: Update the path to the shared directory on your NFS server:
```bash
REPLACE_this_with_your_nfs_path
```

In the end, your line should look like this:
```bash
172.20.0.254:/volume1/Server/Data/media_nas/ /media nfs rw,hard,intr 0 0
```

> **Note**: If you decide not to use an NFS share, follow the steps for disabling this feature in your deployment by commenting out the NFS mount block in Terraform.
{: .prompt-warning }

## Configs

This section focuses on the second folder in the repository, which contains configurations for:

- **getHomepage**
- **Media Stack**
- **Traefik**

### getHomepage Configuration
#### `/docker/homepage/`
No edits are needed in the `homepage` folder. If you'd like to use an existing configuration, you can extract the archive, add your files, and re-archive it. Alternatively, after deployment, configurations will be available in the VM under `/home/homepage/`.

### Media Stack Configuration
#### `/docker/media-stack/`
To ensure the Media Stack services are accessible within your network, update the DNS values in the `labels` section of the `media_stack` configuration. Focus on the `"rule=Host"` entries, where you need to replace the example DNS values with your own domain or DNS configuration from your local DNS server (e.g., Pi-hole, Unbound, Technitium). 

For example:

```yaml
- "traefik.http.routers.jellyseer-media.rule=Host(`jellyseer.local`)"
```

Replace `jellyseer.local` with your custom domain:

```yaml
- "traefik.http.routers.jellyseer-media.rule=Host(`jellyseer.merox.cloud`)"
```

This ensures the services are accessible at `jellyseer.merox.cloud` or any domain configured in your environment.

### Traefik Configuration
**V1**: Return to this step after deployment is complete (config will be in `/home/traefik` on the deployed machine).  
**V2**: Extract the archive, edit as shown below, and re-archive.

#### `docker-compose.yaml`
Update all instances of `yourdomain.com` to your actual domain. Ensure this change is made in all four occurrences.  
**Provider used**: Cloudflare.

#### `.env`
This hidden file contains credentials for the Traefik dashboard. Default credentials:
- **Username**: `user`
- **Password**: `password`

Edit these if needed.

#### `data/config.yml`
Optional file for adding services outside Docker (e.g., your Proxmox IP for SSL access at `proxmox.mydomain.com`).

#### `data/traefik.yml`
Replace `your-cloudflare@email.com` with your Cloudflare email.

### Post-Deployment Step

> After deployment, create a file named `cf_api_token.txt` in `/home/traefik/` with your Cloudflare API token. This step is crucial for starting the Traefik container.
{: .prompt-danger }

Start the container manually:

```bash
/usr/local/bin/docker-compose up &
```

### Additional Resources

For more on Traefik, check out this [detailed guide](https://technotim.live/posts/traefik-3-docker-certificates/).

## Packer Configuration

### `credentials.pkr.hcl`

This file holds sensitive credentials like passwords and API tokens. **Do not upload this file to public repositories**.

```hcl
proxmox_api_url      = "https://your-proxmox-ip-or-fqdn/api2/json"
proxmox_api_token_id = "terraform_user@pam!homelab"
proxmox_api_token_secret = "your-proxmox-api-token-secret"
```

To generate your Proxmox API token, follow this [tutorial](https://youtu.be/dvyeoDBUtsU?si=KI6utW1rG-Gne8I8&t=166).  
More about packer: [here](https://github.com/ChristianLempa/boilerplates/tree/main/packer/).

### `packer.pkr.hcl`

This file contains the plugin configuration required for deployment on Proxmox.

```hcl
packer {
  required_plugins {
    proxmox-iso = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}
```

### `ubuntu-*folder*/ubuntu-server-jammy-docker.pkr.hcl`

1. Replace `YOUR_PROXMOX_NODE_NAME` with the **name of your Proxmox node** where you want the template to be created.
2. Replace `YOUR_IP_DEPLOYMENT_MACHINE` with the **IP of the machine** where the deployment script will run.

### `ubuntu-*folder*/http/user-data`

1. Replace `YOUR_SSH_KEY` with the **SSH key** generated by the `homelab_deploy.sh` script.

## Terraform Configuration

### `terraform.tfvars`
This file holds sensitive credentials like passwords and API tokens. **Do not upload this file to public repositories.**

Example:

```tf
proxmox_api_url      = "https://your-proxmox-ip-or-fqdn/api2/json"
proxmox_api_token_id = "terraform_user@pam!homelab"
proxmox_api_token_secret = "your-proxmox-api-token-secret"
proxmox_host         = "proxmox-host-ip"
proxmox_user         = "proxmox-user"
proxmox_password     = "proxmox-password"
```

To generate your Proxmox API token, follow this [tutorial](https://youtu.be/dvyeoDBUtsU?si=KI6utW1rG-Gne8I8&t=166).

### `modules/docker_vm/main.tf`
Defines the deployment's detailed configuration.

Replace the placeholders with your specific values:
- `YOUR_PROXMOX_NODE_NAME`
- `IP_MACHINE` (VM deployment IP)
- `GateWay_IP`
- `IP_DEPLOYMENT` (same-as-IP_MACHINE)
- `YOUR_SSH_KEY` (generated by the `homelab_deploy.sh` script)

Key features enabled:

#### **NFS/CIFS Mounting**: Supports external storage mounts.  

> **Note**: If you don't want to use any NFS mount, simply comment out this block:
> ```tf
> resource "null_resource" "run_ansible_docker" {
>   depends_on = [local_file.ansible_inventory]
> 
>   provisioner "local-exec" {
>     command = "LC_ALL=C.UTF-8 LANG=C.UTF-8 ansible-playbook -i ../ansible/inventory/inventory.ini ../ansible/roles/nfs_mount/main.yml"
>   }
> }
> ```
{: .prompt-warning }

- **Locales Configuration**: Sets up default locales.
- **Root SSH Login**: Allows root access via SSH.
- **SSH Key Authentication**: Adds your SSH public key for secure access.
- **Ansible Integration**: Automates further configurations.

## Post Deployment

A successful deployment will show the following output in your console:

![Post Deployment Console Output](/assets/img/posts/success.png){: width="600" height="400" }

You can now access your Docker environment via Portainer using the IP (`IP_MACHINE`) and port `9000`. Example:  
```
http://172.20.0.252:9000
```

After setting up your Portainer user, you should see a dashboard like this:  

![Portainer Dashboard Example](/assets/img/posts/homelab-portainer-dashboard.png){: width="700" height="400" }

> **⚠️ Best Practice:** Regularly check your automation, at least monthly, to ensure everything is functioning correctly.
{: .prompt-tip }

If you encounter issues, leave a comment, and I'll assist as soon as possible.

## Conclusion

Thank you for exploring this Homelab as Code project! By combining Packer, Terraform and Ansible, we've streamlined homelab automation and setup. I hope this guide inspires you to enhance your IT skills and optimize your infrastructure.

Happy homelabing, and don't hesitate to share your journey or questions—your feedback is always appreciated! 🚀

### Future Plans

In the coming weeks, I plan to expand this project by adding support for VM deployment using Cloud-Init and Packer. Additionally, I'm considering integrating advanced Ansible projects, such as K3S from TechnoTim, to enhance the automation and scalability of homelab environments.