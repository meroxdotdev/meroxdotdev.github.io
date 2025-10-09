---
title: "Reverse Proxies Homelab and Production"
date: 2025-10-09 10:00:00 +0200
draft: true
categories: [infrastructure]
description: Practical guide to choosing and configuring reverse proxies for homelab and production environments. Compare Traefik, Caddy, and HAProxy with real-world examples and battle-tested configurations.
image:
  path: /assets/img/posts/reverse-proxies-guide.webp
  alt: Reverse Proxies Guide - Traefik, Caddy, HAProxy
---

I've been running reverse proxies for years—first fumbling through Apache configs, then discovering Nginx, and eventually landing on modern solutions like Traefik and Caddy. Here's what I've learned about choosing and configuring reverse proxies for both homelab tinkering and production environments.

## Why You Need a Reverse Proxy

Think of a reverse proxy as your infrastructure's front desk. Instead of exposing every service directly to the internet, you put one smart gateway in front that:

- **Handles SSL/TLS** - One place for all your certificates
- **Routes traffic** - Multiple services, one IP address
- **Adds security** - Rate limiting, authentication, WAF capabilities
- **Enables automation** - Dynamic configuration as services come and go

## The Contenders

### Traefik - The Homelab Champion

After running Traefik for 2+ years, it's become my go-to for anything Docker or Kubernetes-based.

**Why I love it:**
- Auto-discovery of services (Docker labels, Kubernetes Ingress)
- Built-in Let's Encrypt support
- Beautiful dashboard at `traefik.yourdomain.com`
- Perfect for dynamic environments

**Quick Docker Setup:**

```yaml
services:
  traefik:
    image: traefik:v3.2
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/traefik.yml:ro
      - ./acme.json:/acme.json
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(`traefik.local`)"
      - "traefik.http.routers.dashboard.service=api@internal"
```

**traefik.yml:**

```yaml
entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

certificatesResolvers:
  cloudflare:
    acme:
      email: your@email.com
      storage: acme.json
      dnsChallenge:
        provider: cloudflare

providers:
  docker:
    exposedByDefault: false
  file:
    filename: /config.yml
    watch: true

api:
  dashboard: true
```

**Real Example - Jellyfin with Traefik:**

```yaml
services:
  jellyfin:
    image: jellyfin/jellyfin
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.jellyfin.rule=Host(`jellyfin.merox.cloud`)"
      - "traefik.http.routers.jellyfin.entrypoints=websecure"
      - "traefik.http.routers.jellyfin.tls.certresolver=cloudflare"
      - "traefik.http.services.jellyfin.loadbalancer.server.port=8096"
```

That's it. No manual certificate management, no config reloads.

### Caddy - The Zero-Config Dream

Caddy made waves by making HTTPS automatic. Like, seriously automatic.

**Minimal Caddyfile:**

```caddy
jellyfin.merox.cloud {
    reverse_proxy jellyfin:8096
}

portainer.merox.cloud {
    reverse_proxy portainer:9000
}
```

Done. Caddy handles:
- Automatic HTTPS
- Certificate renewal
- HTTP to HTTPS redirects

**Docker Compose with Caddy:**

```yaml
services:
  caddy:
    image: caddy:latest
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config

volumes:
  caddy_data:
  caddy_config:
```

**Advanced Caddyfile:**

```caddy
(common) {
    encode gzip
    header {
        -Server
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
    }
}

jellyfin.merox.cloud {
    import common
    reverse_proxy jellyfin:8096
}

auth.merox.cloud {
    import common
    reverse_proxy authelia:9091
}

*.merox.cloud {
    import common
    tls {
        dns cloudflare {env.CF_API_TOKEN}
    }
}
```

> **My Take:** Use Caddy when you want simplicity. Use Traefik when you want power and ecosystem integration.
{: .prompt-tip }

### HAProxy - The Production Workhorse

When you need absolute reliability and performance, HAProxy is the industry standard. I've seen it handle millions of requests without breaking a sweat.

**Why HAProxy for Production:**
- Battle-tested stability
- Insane performance (can saturate 10Gbps easily)
- Advanced load balancing algorithms
- Detailed metrics and monitoring
- Zero downtime reloads

**Basic HAProxy Config:**

```cfg
global
    log stdout format raw local0
    maxconn 4096
    
defaults
    mode http
    timeout connect 5s
    timeout client 30s
    timeout server 30s
    option httplog
    option dontlognull

frontend http_front
    bind *:80
    bind *:443 ssl crt /etc/haproxy/certs/
    
    # Redirect HTTP to HTTPS
    redirect scheme https code 301 if !{ ssl_fc }
    
    # Route based on domain
    acl is_api hdr(host) -i api.company.com
    acl is_web hdr(host) -i web.company.com
    
    use_backend api_backend if is_api
    use_backend web_backend if is_web

backend api_backend
    balance roundrobin
    option httpchk GET /health
    server api1 192.168.1.10:8080 check
    server api2 192.168.1.11:8080 check
    server api3 192.168.1.12:8080 check

backend web_backend
    balance leastconn
    server web1 192.168.1.20:3000 check
    server web2 192.168.1.21:3000 check
```

**Production Features I Use:**

```cfg
# Rate limiting
frontend http_front
    stick-table type ip size 100k expire 30s store http_req_rate(10s)
    http-request track-sc0 src
    http-request deny deny_status 429 if { sc_http_req_rate(0) gt 100 }

# Health checks with custom pages
backend api_backend
    option httpchk GET /health HTTP/1.1\r\nHost:\ api.company.com
    http-check expect status 200
    
# Circuit breaker pattern
backend api_backend
    option redispatch
    retries 3
    timeout server 5s
```

**Docker Setup:**

```yaml
services:
  haproxy:
    image: haproxy:2.9-alpine
    ports:
      - "80:80"
      - "443:443"
      - "8404:8404"  # Stats page
    volumes:
      - ./haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
      - ./certs:/etc/haproxy/certs:ro
```

## Comparing All Three

| Feature | Traefik | Caddy | HAProxy |
|:--------|:--------|:------|:--------|
| **Auto HTTPS** | ✅ Yes | ✅ Yes | ❌ Manual |
| **Docker Labels** | ✅ Yes | ❌ No | ❌ No |
| **K8s Native** | ✅ Yes | ⚠️ Limited | ⚠️ Limited |
| **Performance** | Good | Good | Excellent |
| **Config Reload** | Automatic | Automatic | Graceful |
| **Learning Curve** | Medium | Easy | Steep |
| **Best For** | Homelab/K8s | Simple setups | Production |

## Real-World Scenarios

### Scenario 1: Personal Homelab

**My Choice:** Traefik

I run Traefik in my Kubernetes cluster and on my Docker host. The automatic service discovery means I just add labels and forget about it.

```yaml
# In my K8s cluster
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: jellyfin
  annotations:
    cert-manager.io/cluster-issuer: cloudflare
spec:
  ingressClassName: traefik
  rules:
  - host: jellyfin.merox.cloud
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: jellyfin
            port:
              number: 8096
  tls:
  - hosts:
    - jellyfin.merox.cloud
    secretName: jellyfin-tls
```

### Scenario 2: Simple Side Project

**My Choice:** Caddy

When I quickly spin up a side project, Caddy is perfect:

```caddy
myproject.dev {
    reverse_proxy backend:3000
    file_server /static/* {
        root /var/www
    }
}
```

### Scenario 3: Production API Gateway

**My Choice:** HAProxy

For production APIs serving thousands of requests per second:

```cfg
frontend api_gateway
    bind *:443 ssl crt /certs/
    
    # Security headers
    http-response set-header Strict-Transport-Security "max-age=31536000"
    http-response set-header X-Frame-Options "DENY"
    
    # API versioning
    acl is_v1 path_beg /v1/
    acl is_v2 path_beg /v2/
    
    use_backend api_v1 if is_v1
    use_backend api_v2 if is_v2

backend api_v1
    balance roundrobin
    option httpchk
    server node1 10.0.1.10:8080 check inter 2s
    server node2 10.0.1.11:8080 check inter 2s
    
backend api_v2
    balance leastconn
    server node3 10.0.2.10:8080 check
    server node4 10.0.2.11:8080 check
```

## Common Pitfalls

### SSL Certificate Management

**Problem:** Certificates expire, renewal fails silently

**Solution with Traefik:**
```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      storage: acme.json
      dnsChallenge:
        provider: cloudflare
        delayBeforeCheck: 0
```

**Solution with Caddy:**
It just works. Seriously.

**Solution with HAProxy:**
Use Certbot with a cron job:
```bash
0 2 * * * certbot renew --post-hook "cat /etc/letsencrypt/live/*/fullchain.pem /etc/letsencrypt/live/*/privkey.pem > /etc/haproxy/certs/cert.pem && systemctl reload haproxy"
```

### Websocket Support

All three handle websockets, but configuration differs:

**Traefik:** Just works with labels
**Caddy:** Add `reverse_proxy` with no special config needed
**HAProxy:** 
```cfg
backend websocket_backend
    timeout tunnel 3600s
    server ws1 192.168.1.30:8080
```

## Monitoring and Debugging

### Traefik Dashboard

Access at `http://localhost:8080` (or your configured domain):

```yaml
api:
  dashboard: true
  insecure: true  # Only for local/testing
```

### Caddy Admin API

```bash
# Get current config
curl localhost:2019/config/

# Check certificate status
curl localhost:2019/pki/certificates/local
```

### HAProxy Stats

```cfg
listen stats
    bind *:8404
    stats enable
    stats uri /
    stats refresh 10s
    stats admin if TRUE
```

Visit `http://localhost:8404` for real-time metrics.

## My Current Setup

Here's what I actually run:

**Homelab:**
- **Traefik** on Kubernetes for all internal services
- **Caddy** on my VPS for simple Docker deployments
- **pfSense** handling the WAN edge

**Why this combo works:**
- Traefik handles dynamic K8s workloads automatically
- Caddy simplifies VPS management (literally set and forget)
- pfSense provides the security perimeter

## Quick Decision Tree

```
Need automatic Docker/K8s discovery? 
  → Traefik

Just want HTTPS with zero config?
  → Caddy

Building production load balancer with high traffic?
  → HAProxy

Running on pfSense/OPNsense?
  → HAProxy (built-in) or Caddy plugin

Need advanced traffic shaping/WAF?
  → Traefik Enterprise or HAProxy + ModSecurity
```

## Final Thoughts

After years of running all three:

- **Start with Caddy** if you're new to reverse proxies
- **Upgrade to Traefik** when you embrace containers
- **Switch to HAProxy** when you need production-grade reliability

And honestly? You can run multiple. I do. Different tools for different jobs.

The "best" reverse proxy is the one you understand and can troubleshoot at 2 AM when something breaks.

> **Pro tip:** Whichever you choose, always keep a backup configuration and document your setup. Future you will thank present you when rebuilding after a disaster.
{: .prompt-warning }

Got questions about specific setups? Drop a comment—I've probably broken it before and learned how to fix it.