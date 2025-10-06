---
title: "SSH Hardening - Securing Your Linux Servers"
date: 2025-10-06 09:00:00 +0300
categories: [infrastructure, security]
description: "Complete guide to hardening SSH on production Linux servers. Learn practical techniques I've implemented across enterprise environments to secure remote access, prevent brute-force attacks, and maintain compliance with security standards."
image:
  path: /assets/img/posts/ssh-hardening-banner.webp
  alt: SSH Security Hardening Guide for Linux Servers
---

After managing Linux infrastructure for several years, I've seen countless security incidents that could have been prevented with proper SSH configuration. The default SSH setup on most distributions is functional but far from secure for production environments. Today, I'm sharing the exact hardening steps I implement on every server I manage.

## Securing SSH Is Important

SSH is the primary entry point to your Linux servers. A poorly configured SSH service is like leaving your front door unlocked with a neon sign saying "Come on in." I've witnessed brute-force attacks hitting servers with thousands of login attempts per hour. Without proper hardening, it's only a matter of time before something gives.

The reality is that automated bots constantly scan the internet for vulnerable SSH services. They try default credentials, exploit weak configurations, and look for any opening to compromise your systems. I learned this the hard way early in my career when I checked auth logs and found over 50,000 failed login attempts in a single day.

## What This Guide Covers

Unlike typical SSH tutorials that just tell you to "change the default port," this guide provides a comprehensive approach based on real production experience:

- Key-based authentication implementation
- SSH daemon configuration hardening
- Two-factor authentication setup
- Connection rate limiting and fail2ban
- Monitoring and log analysis
- Compliance considerations for enterprise environments

## Prerequisites

Before we start, you'll need:
- Root or sudo access to your Linux server
- Basic understanding of SSH connections
- A backup way to access your server (console access, KVM, or recovery mode)
- 30-45 minutes for implementation

> **Critical Warning:** Never lock yourself out. Always test each configuration change in a separate SSH session before closing your original connection.
{: .prompt-warning }

## Part 1: Key-Based Authentication

Password authentication is fundamentally flawed for SSH. Even strong passwords can be compromised through brute-force attacks, keyloggers, or credential stuffing. Key-based authentication eliminates these risks.

### Generate SSH Key Pair

On your local machine (not the server):

```bash
# Generate ED25519 key (recommended in 2025)
ssh-keygen -t ed25519 -C "your_email@example.com" -f ~/.ssh/id_prod_server

# Alternative: RSA 4096-bit key for older systems
ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f ~/.ssh/id_prod_server
```

Why ED25519? It's faster, more secure, and uses shorter keys than RSA. I've switched all my infrastructure to ED25519 and never looked back.

### Deploy Public Key to Server

```bash
# Copy your public key to the server
ssh-copy-id -i ~/.ssh/id_prod_server.pub username@server_ip

# Manual method if ssh-copy-id isn't available
cat ~/.ssh/id_prod_server.pub | ssh username@server_ip "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

### Test Key Authentication

Before disabling password authentication, verify key-based login works:

```bash
ssh -i ~/.ssh/id_prod_server username@server_ip
```

If you can log in without entering a password, you're good to proceed.

### Set Correct Permissions

SSH is strict about permissions. Incorrect permissions will cause authentication to fail:

```bash
# On the server
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chmod 600 ~/.ssh/id_ed25519  # if private key is on server
```

## Part 2: SSH Daemon Configuration

The real hardening happens in `/etc/ssh/sshd_config`. I'll walk you through each critical setting.

### Backup Original Configuration

Always create a backup before making changes:

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%F)
```

### Edit SSH Configuration

```bash
sudo nano /etc/ssh/sshd_config
```

### Essential Security Settings

Here's my production-ready configuration:

```bash
# Network Settings
Port 2222  # Change from default port 22
AddressFamily inet  # IPv4 only (use 'any' for IPv4+IPv6)
ListenAddress 0.0.0.0  # Or specify exact IP

# Authentication Settings
PermitRootLogin no  # Never allow direct root login
PubkeyAuthentication yes
PasswordAuthentication no  # Disable password auth
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Key Types (ED25519 preferred)
PubkeyAcceptedKeyTypes ssh-ed25519,rsa-sha2-512,rsa-sha2-256

# Limit user access
AllowUsers deployer sysadmin  # Only specific users
# AllowGroups ssh-users  # Or use groups

# Session Settings
MaxAuthTries 3  # Limit authentication attempts
MaxSessions 2  # Limit concurrent sessions
LoginGraceTime 30  # Timeout for authentication
ClientAliveInterval 300  # Keep-alive messages
ClientAliveCountMax 2  # Disconnect after 2 missed keep-alives

# Disable Dangerous Features
X11Forwarding no
PermitUserEnvironment no
AllowAgentForwarding no
AllowTcpForwarding no
PermitTunnel no

# Logging
SyslogFacility AUTH
LogLevel VERBOSE  # Detailed logging for security analysis

# Modern Cryptography (2025 standards)
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

# Security Headers
HostbasedAuthentication no
IgnoreRhosts yes
```

### Validate Configuration

Before restarting SSH, validate your configuration:

```bash
sudo sshd -t
```

If there are no errors, restart the SSH service:

```bash
# SystemD systems
sudo systemctl restart sshd

# Check status
sudo systemctl status sshd
```

> **Critical:** Keep your current SSH session open. Open a NEW terminal and test the connection. Only after confirming the new session works should you close the original.
{: .prompt-danger }

### Update Firewall Rules

If you changed the SSH port, update your firewall:

```bash
# UFW (Ubuntu/Debian)
sudo ufw allow 2222/tcp
sudo ufw delete allow 22/tcp
sudo ufw reload

# firewalld (RHEL/CentOS)
sudo firewall-cmd --permanent --add-port=2222/tcp
sudo firewall-cmd --permanent --remove-service=ssh
sudo firewall-cmd --reload
```

## Part 3: Two-Factor Authentication

Adding 2FA provides an additional security layer. Even if someone steals your private key, they can't access the server without the second factor.

### Install Google Authenticator

```bash
# Ubuntu/Debian
sudo apt install libpam-google-authenticator

# RHEL/CentOS
sudo yum install google-authenticator
```

### Configure 2FA for Your User

```bash
google-authenticator
```

Answer the prompts:
- Do you want time-based tokens? **Yes**
- Update ~/.google_authenticator? **Yes**
- Disallow multiple uses? **Yes**
- Increase time window? **No** (unless you have time sync issues)
- Enable rate-limiting? **Yes**

Scan the QR code with your authenticator app (Google Authenticator, Authy, etc.).

### Configure PAM

Edit PAM configuration:

```bash
sudo nano /etc/pam.d/sshd
```

Add at the top:

```bash
auth required pam_google_authenticator.so nullok
```

The `nullok` option allows users without 2FA configured to still login. Remove it once all users have 2FA set up.

### Enable 2FA in SSH

Edit `/etc/ssh/sshd_config`:

```bash
ChallengeResponseAuthentication yes
AuthenticationMethods publickey,keyboard-interactive
```

Restart SSH:

```bash
sudo systemctl restart sshd
```

Now connections require both your SSH key AND the 2FA code.

## Part 4: Host-Based Authentication (Advanced)

Host-based authentication allows one server to authenticate to another based on the client machine's host key, rather than user keys. This is particularly useful in enterprise environments where you have trusted servers that need automated, passwordless communication.

> **Important:** Host-based authentication should only be used in controlled environments where you trust the client machines completely. It's not a replacement for user key authentication, but a complement for specific use cases.
{: .prompt-warning }

### When to Use Host-Based Authentication

I use host-based authentication in these scenarios:
- Automated backup systems pulling data from multiple servers
- Configuration management systems (Ansible, Puppet)
- Monitoring systems that need to execute remote commands
- Database replication between trusted servers
- CI/CD pipelines deploying to production

### Architecture Overview

Host-based authentication works like this:
1. Client machine has a host key pair in `/etc/ssh/`
2. Server trusts specific client hostnames
3. During connection, client proves its identity using the host key
4. Server verifies the hostname and host key match

### Prerequisites

- Root access on both client and server
- Proper DNS or `/etc/hosts` entries for hostname resolution
- Network trust between machines

### Step 1: Enable Host-Based Authentication on Server

Edit `/etc/ssh/sshd_config` on the **server** (the machine being connected to):

```bash
sudo nano /etc/ssh/sshd_config
```

Add or modify these settings:

```bash
# Enable host-based authentication
HostbasedAuthentication yes

# Trust user@host combinations (more secure)
HostbasedUsesNameFromPacketOnly yes

# Require both user key and host-based auth (optional, very secure)
# AuthenticationMethods publickey,hostbased

# Accept these key types for host authentication
HostbasedAcceptedKeyTypes ssh-ed25519,rsa-sha2-512,rsa-sha2-256

# Don't ignore rhosts (needed for host-based auth)
IgnoreRhosts no

# Still require proper user mapping
IgnoreUserKnownHosts no
```

Restart SSH:

```bash
sudo systemctl restart sshd
```

### Step 2: Configure Trusted Hosts on Server

Create or edit `/etc/ssh/shosts.equiv` on the **server**:

```bash
sudo nano /etc/ssh/shosts.equiv
```

Add trusted hostnames (one per line):

```bash
# Format: hostname [username]
backup-server.example.com deployer
monitoring.example.com monitor
ci-runner-01.example.com jenkins
```

Set proper permissions:

```bash
sudo chmod 600 /etc/ssh/shosts.equiv
sudo chown root:root /etc/ssh/shosts.equiv
```

Alternative per-user configuration:

```bash
# User-specific trusted hosts
nano ~/.shosts

# Add trusted hosts
backup-server.example.com
monitoring.example.com
```

### Step 3: Configure Client Machine

On the **client** machine (the one initiating connections), edit `/etc/ssh/ssh_config` or `~/.ssh/config`:

```bash
sudo nano /etc/ssh/ssh_config
```

Add these settings:

```bash
# Enable host-based authentication
HostbasedAuthentication yes

# Send local hostname
EnableSSHKeysign yes

# Prefer host-based auth
PreferredAuthentications hostbased,publickey,password
```

### Step 4: Configure SSH Keysign

The `ssh-keysign` program must be setuid root to access host keys:

```bash
# Verify ssh-keysign location
which ssh-keysign
# Usually: /usr/lib/openssh/ssh-keysign or /usr/libexec/openssh/ssh-keysign

# Set proper permissions
sudo chmod 4711 /usr/lib/openssh/ssh-keysign
# or
sudo chmod 4711 /usr/libexec/openssh/ssh-keysign
```

### Step 5: Distribute Host Public Keys

On the **client** machine, find the host public key:

```bash
# Usually ssh_host_ed25519_key.pub or ssh_host_rsa_key.pub
sudo cat /etc/ssh/ssh_host_ed25519_key.pub
```

Copy this key to the **server's** known hosts file:

```bash
# On the server
sudo nano /etc/ssh/ssh_known_hosts
```

Add an entry in this format:

```bash
# Format: hostname,ip key-type public-key
backup-server.example.com,192.168.1.10 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILo...
monitoring.example.com,192.168.1.20 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIXy...
```

Set proper permissions:

```bash
sudo chmod 644 /etc/ssh/ssh_known_hosts
sudo chown root:root /etc/ssh/ssh_known_hosts
```

### Step 6: Test Host-Based Authentication

From the **client** machine, test the connection:

```bash
# Test with verbose output
ssh -v deployer@production-server.example.com

# Look for this in the output:
# "Offering public key: /etc/ssh/ssh_host_ed25519_key"
# "Server accepts key: /etc/ssh/ssh_host_ed25519_key"
# "Authentication succeeded (hostbased)"
```

### Automation Script for Multiple Clients

I use this script to distribute host keys from multiple clients to a central server:

Save as `/usr/local/bin/distribute-host-keys.sh` on the **server**:

```bash
#!/bin/bash
# Collect and distribute host keys for host-based authentication

KNOWN_HOSTS="/etc/ssh/ssh_known_hosts"
TEMP_KEYS="/tmp/host_keys_collection.txt"

# List of client machines
CLIENTS=(
    "backup-server.example.com"
    "monitoring.example.com"
    "ci-runner-01.example.com"
)

echo "Collecting host keys from client machines..."
> $TEMP_KEYS

for client in "${CLIENTS[@]}"; do
    echo "Fetching key from $client..."
    
    # Get hostname and IP
    IP=$(dig +short $client | tail -1)
    
    # Fetch the host key
    KEY=$(ssh-keyscan -t ed25519 $client 2>/dev/null)
    
    if [ -n "$KEY" ]; then
        # Format: hostname,ip key-type key
        echo "$client,$IP $(echo $KEY | awk '{print $2, $3}')" >> $TEMP_KEYS
        echo "  ✓ Key collected from $client"
    else
        echo "  ✗ Failed to get key from $client"
    fi
done

# Backup existing known_hosts
if [ -f $KNOWN_HOSTS ]; then
    cp $KNOWN_HOSTS ${KNOWN_HOSTS}.backup.$(date +%F)
fi

# Add new keys
cat $TEMP_KEYS >> $KNOWN_HOSTS

# Remove duplicates and sort
sort -u $KNOWN_HOSTS -o $KNOWN_HOSTS

# Set permissions
chmod 644 $KNOWN_HOSTS

echo "Host keys distributed successfully!"
echo "Backup saved to ${KNOWN_HOSTS}.backup.$(date +%F)"
```

Make it executable:

```bash
sudo chmod +x /usr/local/bin/distribute-host-keys.sh
sudo /usr/local/bin/distribute-host-keys.sh
```

### Security Considerations

**Pros:**
- No credential management for automated processes
- Host identity verification
- Useful for trusted server-to-server communication

**Cons:**
- If client machine is compromised, attacker gains access
- Harder to audit than user-based authentication
- Requires careful hostname management

**Best Practices I Follow:**

1. **Use with User Keys:** Combine with publickey authentication:
   ```bash
   AuthenticationMethods publickey,hostbased
   ```

2. **Limit to Specific Commands:** Use `command=` in authorized_keys for restriction

3. **Network Segmentation:** Only allow host-based auth from trusted network segments

4. **Regular Audits:** Review `/etc/ssh/shosts.equiv` monthly

5. **Logging:** Ensure verbose logging to track host-based authentications:
   ```bash
   LogLevel VERBOSE
   ```

6. **Firewall Rules:** Restrict SSH access to only trusted client IPs

### Monitoring Host-Based Authentications

Add to your monitoring script:

```bash
# Check for host-based authentication attempts
echo "Host-Based Authentications:" >> $REPORT_FILE
grep "hostbased" /var/log/auth.log | tail -20 >> $REPORT_FILE
echo "" >> $REPORT_FILE
```

### Troubleshooting

**Connection fails with "Permission denied":**

1. Check server logs:
   ```bash
   sudo journalctl -u sshd -n 50 | grep hostbased
   ```

2. Verify hostname resolution:
   ```bash
   # On server
   hostname -f
   # Should match what's in shosts.equiv
   ```

3. Check ssh-keysign permissions:
   ```bash
   ls -l /usr/lib/openssh/ssh-keysign
   # Should be: -rws--x--x (4711)
   ```

4. Verify host key on server:
   ```bash
   sudo grep "$(hostname)" /etc/ssh/ssh_known_hosts
   ```

**Debug mode:**

```bash
# On client, test with maximum verbosity
ssh -vvv -o PreferredAuthentications=hostbased user@server
```

### Revoking Host Access

To revoke a client's access:

1. Remove from `/etc/ssh/shosts.equiv`:
   ```bash
   sudo nano /etc/ssh/shosts.equiv
   # Delete the line with the hostname
   ```

2. Remove from `/etc/ssh/ssh_known_hosts`:
   ```bash
   sudo ssh-keygen -R hostname.example.com -f /etc/ssh/ssh_known_hosts
   ```

3. Restart SSH:
   ```bash
   sudo systemctl restart sshd
   ```

### Real-World Example: Backup Server Setup

Here's how I configure a backup server to pull data from multiple production servers:

**On production servers** (`/etc/ssh/sshd_config`):
```bash
HostbasedAuthentication yes
Match User backup
    HostbasedAuthentication yes
    PasswordAuthentication no
    AllowUsers backup
```

**On production servers** (`/etc/ssh/shosts.equiv`):
```bash
backup-server.example.com backup
```

**On backup server** (`/etc/ssh/ssh_config`):
```bash
Host prod-*
    HostbasedAuthentication yes
    PreferredAuthentications hostbased
    User backup
```

Now the backup server can automatically connect:
```bash
rsync -avz prod-web-01:/var/www/ /backup/web-01/
```


## Part 5: Fail2Ban Protection

Fail2ban monitors log files and automatically blocks IP addresses that show malicious behavior.

### Install Fail2Ban

```bash
# Ubuntu/Debian
sudo apt install fail2ban

# RHEL/CentOS
sudo yum install epel-release
sudo yum install fail2ban
```

### Configure Fail2Ban

Create a local configuration file:

```bash
sudo nano /etc/fail2ban/jail.local
```

```ini
[DEFAULT]
# Ban IP for 1 hour after 3 failed attempts within 10 minutes
bantime = 3600
findtime = 600
maxretry = 3
destemail = your_email@example.com
sendername = Fail2Ban
action = %(action_mwl)s

[sshd]
enabled = true
port = 2222  # Match your SSH port
filter = sshd
logpath = /var/log/auth.log  # Debian/Ubuntu
# logpath = /var/log/secure  # RHEL/CentOS
maxretry = 3
bantime = 3600
```

### Start Fail2Ban

```bash
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### Monitor Fail2Ban

```bash
# Check status
sudo fail2ban-client status sshd

# View banned IPs
sudo fail2ban-client get sshd banned

# Unban an IP
sudo fail2ban-client set sshd unbanip 192.168.1.100
```


## Part 6: SSH Connection Management

### Create SSH Config for Easy Access

On your local machine, create `~/.ssh/config`:

```bash
Host production-server
    HostName server_ip
    Port 2222
    User deployer
    IdentityFile ~/.ssh/id_prod_server
    ServerAliveInterval 60
    ServerAliveCountMax 3
    
Host staging-server
    HostName staging_ip
    Port 2222
    User deployer
    IdentityFile ~/.ssh/id_staging_server
    ProxyJump bastion-host  # Jump through bastion
```

Now you can connect simply with:

```bash
ssh production-server
```

### SSH Agent for Key Management

Load keys into SSH agent to avoid re-entering passphrases:

```bash
# Start agent
eval "$(ssh-agent -s)"

# Add keys
ssh-add ~/.ssh/id_prod_server

# List loaded keys
ssh-add -l
```

## Part 7: Monitoring and Logging

Security is useless without proper monitoring. You need to know what's happening on your servers.

### Enable Detailed SSH Logging

In `/etc/ssh/sshd_config`:

```bash
LogLevel VERBOSE
```

### Monitor Authentication Logs

```bash
# Real-time monitoring (Ubuntu/Debian)
sudo tail -f /var/log/auth.log

# Real-time monitoring (RHEL/CentOS)
sudo tail -f /var/log/secure

# Search for failed attempts
sudo grep "Failed password" /var/log/auth.log | tail -20

# Successful logins
sudo grep "Accepted publickey" /var/log/auth.log | tail -20
```

### Create Monitoring Script

Save this as `/usr/local/bin/ssh-monitor.sh`:

```bash
#!/bin/bash
# SSH Security Monitoring Script

LOG_FILE="/var/log/auth.log"  # Change for RHEL: /var/log/secure
REPORT_FILE="/var/log/ssh-security-report.txt"

echo "SSH Security Report - $(date)" > $REPORT_FILE
echo "================================" >> $REPORT_FILE
echo "" >> $REPORT_FILE

echo "Failed Login Attempts:" >> $REPORT_FILE
grep "Failed password" $LOG_FILE | awk '{print $1, $2, $3, $11}' | sort | uniq -c | sort -nr | head -20 >> $REPORT_FILE
echo "" >> $REPORT_FILE

echo "Successful Logins:" >> $REPORT_FILE
grep "Accepted publickey" $LOG_FILE | awk '{print $1, $2, $3, $9, $11}' | tail -20 >> $REPORT_FILE
echo "" >> $REPORT_FILE

echo "Active SSH Sessions:" >> $REPORT_FILE
who >> $REPORT_FILE
echo "" >> $REPORT_FILE

echo "Current Fail2Ban Bans:" >> $REPORT_FILE
fail2ban-client status sshd 2>/dev/null >> $REPORT_FILE

cat $REPORT_FILE
```

Make it executable and run daily:

```bash
sudo chmod +x /usr/local/bin/ssh-monitor.sh

# Add to crontab
echo "0 9 * * * /usr/local/bin/ssh-monitor.sh | mail -s 'SSH Security Report' your_email@example.com" | sudo crontab -
```

## Part 8: Troubleshooting Common Issues

### Can't Connect After Changes

1. **Check if SSH is running:**
   ```bash
   sudo systemctl status sshd
   ```

2. **Verify firewall rules:**
   ```bash
   sudo ufw status  # or firewall-cmd --list-all
   ```

3. **Test configuration:**
   ```bash
   sudo sshd -t
   ```

4. **Check logs:**
   ```bash
   sudo journalctl -u sshd -n 50
   ```

### Permission Denied (publickey)

This usually means SSH keys aren't configured correctly:

```bash
# Check permissions
ls -la ~/.ssh

# Should be:
# .ssh directory: 700
# authorized_keys: 600
# private keys: 600

# Fix permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

### Too Many Authentication Failures

If you have multiple keys in your SSH agent:

```bash
# Clear agent
ssh-add -D

# Add only the required key
ssh-add ~/.ssh/id_prod_server

# Or specify in connection
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_prod_server user@server
```

### 2FA Code Not Working

1. Check time synchronization on server:
   ```bash
   timedatectl status
   ```

2. If time is off, sync it:
   ```bash
   sudo systemctl restart chrony  # or ntpd
   ```

## Part 9: Compliance and Best Practices

### Regular Security Audits

I run these checks monthly:

```bash
# Review authorized_keys
cat ~/.ssh/authorized_keys

# Check for weak keys
for key in /etc/ssh/ssh_host_*_key.pub; do ssh-keygen -lf $key; done

# Review SSH logs for anomalies
sudo grep -i "POSSIBLE BREAK-IN" /var/log/auth.log

# Check for users with empty passwords
sudo awk -F: '($2 == "") {print $1}' /etc/shadow
```

### Documentation Requirements

For enterprise environments, document:
- SSH configuration changes
- List of authorized users and their keys
- Justification for any non-standard settings
- Incident response procedures
- Key rotation schedule

### Key Rotation Policy

I rotate SSH keys annually:

1. Generate new key pair
2. Deploy new public key to all servers
3. Test new key works on all systems
4. Remove old public key
5. Update documentation

## Conclusion

SSH hardening isn't optional for production servers. The techniques in this guide have kept my infrastructure secure across multiple companies and thousands of servers. I've prevented countless intrusion attempts simply by following these practices.

The most important takeaways:
- Never rely on passwords alone
- Change default configurations
- Monitor everything
- Test before you deploy
- Always have a backup access method

Remember that security is a process, not a destination. Stay updated on new vulnerabilities, regularly audit your configurations, and never get complacent.

If you implement even half of these recommendations, you'll be ahead of 90% of servers on the internet. Start with key-based authentication and work your way through the other sections as time allows.

Have questions about implementing these changes? Found a configuration that works better in your environment? Drop a comment below – I'd love to hear about your experiences with SSH hardening.