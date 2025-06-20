---
title: Complete Guide - SMB/CIFS Authentication with Active Directory on Linux
date: 2025-06-01 10:00:00 +0300
categories: [infrastructure]
tags: [samba, sssd, active-directory, smb, cifs, kerberos, realmd, enterprise, authentication, linux-administration]
description: Comprehensive step-by-step tutorial for setting up SMB/CIFS file sharing with Active Directory authentication on Linux servers. Covers SSSD, Samba, Kerberos configuration, troubleshooting, and security best practices.
image:
  path: /assets/img/posts/smb-cifs-ad-authentication-banner.webp
  alt: SMB/CIFS Active Directory Authentication on Linux
---

Learn how to integrate Linux SMB file servers with Active Directory for seamless Windows authentication.

## Introduction

After many days of configuration and internet research, I couldn't find anything that covered all the information needed to integrate this type of configuration into a system. My current job, for example, absolutely requires centralized SSSD across all Linux servers, so below is the configuration I managed to implement on both RedHat 8 and OpenSUSE 15.6.

## Architecture Overview

The solution combines several components:
- **Samba** - SMB/CIFS file server
- **SSSD** - System Security Services Daemon for AD integration
- **Kerberos** - Authentication protocol
- **realmd** - Domain join utility

## Prerequisites

### System Requirements
- Red Hat/CentOS/Rocky Linux 8+ or Ubuntu 20.04+
- Network connectivity to Active Directory Domain Controllers
- DNS resolution properly configured
- NTP/Chrony for time synchronization

### Required Information
- Domain name: `company.com`
- Domain Controller: `dc1.company.com`
- Domain admin account with join privileges
- Target OU for computer objects (optional)

## Step 1: Package Installation

### RHEL/CentOS/Rocky Linux

```bash
# Install required packages
sudo dnf install -y realmd sssd oddjob oddjob-mkhomedir adcli \
    samba-common-tools krb5-workstation chrony samba samba-client \
    cifs-utils policycoreutils-python-utils

# Enable and start services
sudo systemctl enable --now chronyd
sudo systemctl enable --now sssd
```

### Ubuntu/Debian

```bash
# Update package list
sudo apt update

# Install required packages
sudo apt install -y realmd sssd sssd-tools libnss-sss libpam-sss \
    adcli samba-common-bin krb5-user chrony samba samba-client \
    cifs-utils policycoreutils-python-utils

# Enable and start services
sudo systemctl enable --now chrony
sudo systemctl enable --now sssd
```

## Step 2: DNS and Time Configuration

### DNS Configuration

```bash
# Verify DNS resolution
dig company.com
dig _ldap._tcp.company.com SRV

# Find domain controllers
dig +short NS company.com
```

Edit `/etc/resolv.conf`:

```bash
sudo nano /etc/resolv.conf
```

```
nameserver 192.168.1.10  # Primary DC IP
nameserver 192.168.1.11  # Secondary DC IP (optional)
search company.com
domain company.com
```

### Time Synchronization

```bash
# Configure chrony to sync with domain controller
sudo nano /etc/chrony.conf
```

Add/modify:

```
server dc1.company.com iburst prefer
server dc2.company.com iburst
```

```bash
# Restart and verify
sudo systemctl restart chronyd
chrony sources -v
timedatectl status
```

## Step 3: Kerberos Configuration

```bash
# Create Kerberos configuration
sudo nano /etc/krb5.conf
```

```ini
[libdefaults]
    default_realm = COMPANY.COM
    dns_lookup_kdc = true
    dns_lookup_realm = false
    rdns = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true
    udp_preference_limit = 0

[realms]
    COMPANY.COM = {
        kdc = dc1.company.com
        admin_server = dc1.company.com
        default_domain = company.com
    }

[domain_realm]
    .company.com = COMPANY.COM
    company.com = COMPANY.COM

[logging]
    kdc = FILE:/var/log/krb5/krb5kdc.log
    admin_server = FILE:/var/log/krb5/kadmind.log
    default = SYSLOG:NOTICE:DAEMON
```

### Test Kerberos

```bash
# Test authentication
kinit administrator@COMPANY.COM
klist
kdestroy
```

## Step 4: Domain Join with realmd

### Discover Domain

```bash
# Discover the domain
sudo realm discover company.com
```

### Join Domain

```bash
# Join domain with SSSD and Samba integration
sudo realm join company.com -U administrator \
    --client-software=sssd \
    --membership-software=samba 
```

### Verify Join

```bash
# Check realm status
sudo realm list

# Verify computer account
net ads testjoin
```

## Step 5: SSSD Configuration

```bash
# Edit SSSD configuration
sudo nano /etc/sssd/sssd.conf
```

```ini
[sssd]
enable_files_domain = true
domains = company.com
config_file_version = 2
services = nss, pam

[domain/local]
id_provider = files

[domain/company.com]
# Basic AD configuration
ad_domain = company.com
krb5_realm = COMPANY.COM
realmd_tags = manages-system joined-with-samba
cache_credentials = True
id_provider = ad
ad_update_samba_machine_account_password = True

# User/Group formatting
full_name_format = %3$s\%1$s
use_fully_qualified_names = False
fallback_homedir = /home/%u
default_shell = /bin/bash

# ID mapping (disable for consistent UIDs across servers)
ldap_id_mapping = False

# Kerberos settings
krb5_store_password_if_offline = True

# Access control
access_provider = simple
simple_allow_groups = linuxadmins@company.com, itstaff@company.com
simple_allow_users = testuser@company.com

# Performance tuning
enumerate = False
cache_first = True
```

### Set permissions and restart

```bash
sudo chmod 600 /etc/sssd/sssd.conf
sudo systemctl restart sssd
sudo systemctl enable sssd
```

## Step 6: NSS Configuration

The nsswitch.conf should include both `sss` and `winbind`:

```bash
sudo nano /etc/nsswitch.conf
```

Key lines should look like:

```
passwd:     files sss winbind
group:      files sss winbind
shadow:     files sss
netgroup:   sss files
```

## Step 7: Samba Configuration

### Create Samba configuration

```bash
sudo nano /etc/samba/smb.conf
```

```ini
[global]
    # Domain settings
    realm = COMPANY.COM
    workgroup = COMPANY
    security = ads
    
    # Kerberos configuration
    kerberos method = secrets and keytab
    dedicated keytab file = /etc/krb5.keytab
    
    # Logging
    log file = /var/log/samba/log.%m
    log level = 2
    
    # VFS and ACL support
    vfs objects = acl_xattr
    map acl inherit = yes
    store dos attributes = yes
    
    # User mapping
    template homedir = /home/%U
    template shell = /bin/bash
    
    # ID mapping configuration
    idmap config * : backend = tdb
    idmap config * : range = 10000-199999
    idmap config COMPANY : range = 200000-2147483647
    idmap config COMPANY : backend = sss
    
    # Security settings
    client signing = mandatory
    server signing = mandatory
    
    # Performance
    socket options = TCP_NODELAY IPTOS_LOWDELAY
    
# Example share configuration
[shared]
    path = /srv/shared
    read only = no
    browsable = yes
    valid users = @linuxadmins@company.com, @itstaff@company.com
    force group = linuxadmins
    create mask = 0664
    directory mask = 0775
    
[data]
    path = /srv/data
    read only = no
    browsable = yes
    valid users = @dataaccess@company.com
    force group = dataaccess
    create mask = 0660
    directory mask = 0770
    
[homes]
    comment = Home Directories
    browsable = no
    read only = no
    create mask = 0700
    directory mask = 0700
```

### Create share directories

```bash
# Create directories
sudo mkdir -p /srv/shared /srv/data

# Set permissions
sudo chgrp linuxadmins /srv/shared
sudo chmod 775 /srv/shared
sudo chgrp dataaccess /srv/data
sudo chmod 770 /srv/data

# Set SELinux contexts (RHEL/CentOS)
sudo setsebool -P samba_export_all_ro=1 samba_export_all_rw=1
sudo semanage fcontext -a -t samba_share_t "/srv/shared(/.*)?"
sudo semanage fcontext -a -t samba_share_t "/srv/data(/.*)?"
sudo restorecon -R /srv/shared /srv/data
```

## Step 8: Join Samba to Domain

### Alternative join method with net command

```bash
# Join using net command (alternative to realm join)
sudo net ads join -U administrator

# Verify join
sudo net ads testjoin
# Should return: Join is OK
```

### Test authentication

```bash
# Test user lookup
getent passwd testuser@company.com
id testuser@company.com

# Test group lookup
getent group linuxadmins@company.com
```

## Step 9: Service Management and Testing

### Start Samba services

```bash
sudo systemctl enable --now smb winbind
sudo systemctl status smb winbind
```

### Test SMB shares

```bash
# List shares
sudo smbclient -L localhost -U testuser@company.com

# Test access to share
sudo smbclient //localhost/shared -U testuser@company.com

# From Windows client
# \\linux-server\shared
```

## Step 10: Troubleshooting and Maintenance

### Cache Management

```bash
# Clear SSSD cache
sudo sss_cache -E
sudo systemctl restart sssd

# Clear Samba cache
sudo net cache flush

# Remove Samba TDB files (if corruption suspected)
sudo systemctl stop smb winbind
sudo rm -f /var/lib/samba/*.tdb
sudo systemctl start winbind smb
```

### Log Analysis

```bash
# SSSD logs
sudo tail -f /var/log/sssd/sssd_company.com.log

# Samba logs
sudo tail -f /var/log/samba/log.smbd

# Enable debug logging in SSSD
sudo nano /etc/sssd/sssd.conf
# Add: debug_level = 9 in [domain/company.com] section
sudo systemctl restart sssd
```

### Connection Testing

```bash
# Test AD connectivity
sudo net ads info

# Test user authentication
sudo net ads lookup testuser

# Test group membership
sudo net ads group info "linuxadmins"

# Kerberos ticket status
klist -k /etc/krb5.keytab
```

### Performance Monitoring

```bash
# Monitor active SMB connections
sudo smbstatus

# Check winbind status
sudo wbinfo -t  # Trust secret
sudo wbinfo -u  # List users
sudo wbinfo -g  # List groups
```

## Advanced Configuration

### User and Group Mapping

```bash
# Map Windows groups to Linux groups
sudo net groupmap add ntgroup="Domain Admins" unixgroup=wheel type=domain

# List current mappings
sudo net groupmap list
```

### Share-level Permissions

```ini
# Advanced share configuration
[finance]
    path = /srv/finance
    read only = no
    browsable = yes
    valid users = @finance@company.com
    admin users = @financeadmins@company.com
    force group = finance
    create mask = 0640
    directory mask = 0750
    veto files = /*.mp3/*.avi/*.mpg/
    hide unreadable = yes
```

## Security Considerations

### Firewall Configuration

```bash
# Open required ports
sudo firewall-cmd --permanent --add-service=samba
sudo firewall-cmd --permanent --add-port=445/tcp
sudo firewall-cmd --permanent --add-port=139/tcp
sudo firewall-cmd --reload
```

### SELinux Configuration (RHEL/CentOS)

```bash
# Required SELinux booleans
sudo setsebool -P samba_domain_controller=on
sudo setsebool -P use_samba_home_dirs=on
sudo setsebool -P samba_enable_home_dirs=on

# Check SELinux status
sudo getsebool -a | grep samba
```

### Regular Maintenance Tasks

```bash
# Create maintenance script
sudo nano /usr/local/bin/samba-maintenance.sh
```

```bash
#!/bin/bash
# Samba/AD maintenance script

# Refresh machine account password
net ads changetrustpw

# Clear old cache entries
sss_cache -E

# Backup TDB files
tdbbackup /var/lib/samba/*.tdb

# Check domain trust
net ads testjoin

echo "Maintenance completed: $(date)"
```

```bash
sudo chmod +x /usr/local/bin/samba-maintenance.sh

# Add to crontab (weekly maintenance)
echo "0 2 * * 0 /usr/local/bin/samba-maintenance.sh >> /var/log/samba-maintenance.log 2>&1" | sudo crontab -
```

## Common Issues and Solutions

### Issue: "NT_STATUS_ACCESS_DENIED" errors

```bash
# Check user permissions
id username@company.com

# Verify share configuration
sudo testparm -s

# Check SELinux contexts
ls -Z /srv/shared
```

### Issue: Users not resolving

```bash
# Clear cache and restart services
sudo sss_cache -E
sudo systemctl restart sssd winbind

# Check NSS configuration
getent passwd username@company.com
```

### Issue: Authentication failures

```bash
# Check Kerberos tickets
klist
kinit username@COMPANY.COM

# Verify time sync
chrony sources -v

# Check domain trust
net ads testjoin
```

## Conclusion

This setup provides robust SMB/CIFS file sharing with Active Directory authentication. The combination of SSSD for user resolution and Samba for file services offers excellent performance and reliability. Regular maintenance and monitoring ensure continued operation in enterprise environments.

Key benefits of this configuration:
- Seamless Windows integration
- Centralized user management
- Kerberos SSO support
- Scalable for large environments
- Comprehensive logging and monitoring

Remember to regularly update your systems and monitor the logs for any authentication or connectivity issues.