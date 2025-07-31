---
title: Deploying a Kubernetes-Based Media Server
date: 2024-03-06 10:00:00 +0200
categories: [infrastructure]
tags: [kubernetes, self-hosting, media-server, jellyfin, radarr, sonarr]
description: Well-crafted tutorial to deploy a media server on my Kubernetes cluster
image:
  path: /assets/img/posts/kubernetes-media-server.webp
  alt: Kubernetes Media Server Architecture
---

For a long time, I've been on the hunt for a comprehensive and well-crafted tutorial to deploy a media server on my Kubernetes cluster. This media server stack includes Jellyfin, Radarr, Sonarr, Jackett, and qBittorrent. Let's briefly dive into what each component brings to our setup.

## Components Overview

| Application | Description |
|:------------|:------------|
| **Jellyfin** | An open-source media system that provides a way to manage and stream your media library across various devices. |
| **Radarr** | A movie collection manager for Usenet and BitTorrent users. It automates the process of searching for movies, downloading, and managing your movie library. |
| **Sonarr** | Similar to Radarr but for TV shows. It keeps track of your series, downloads new episodes, and manages your collection with ease. |
| **Jackett** | Acts as a proxy server, translating queries from other apps (like Sonarr or Radarr) into queries that can be understood by a wide array of torrent search engines. |
| **qBittorrent** | A powerful BitTorrent client that handles your downloads. Paired with Jackett, it streamlines finding and downloading media content. |
| **Gluetun** | A lightweight, open-source VPN client for Docker environments, supporting multiple VPN providers to secure and manage internet connections across containerized applications. |

The configuration for these applications is hosted on Longhorn storage, ensuring resilience and ease of management, while the media (movies, shows, books, etc.) is stored on a Synology NAS DS223. The NAS location is utilized as a Persistent Volume (PV) through NFS 4.1 by Kubernetes.

## Synology NAS NFS Setup for Kubernetes

If you use Synology NAS, this is the rule I created for my NFS share which will be mounted on kubernetes side.

![NFS Rule Configuration](/assets/img/posts/nfs_rule_nas.png){: width="700" height="400" }
_NFS rule configuration on Synology NAS_

## Configuring PVC and PV for NFS Share

### Media Storage

Create `nfs-media-pv-and-pvc.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: jellyfin-videos
spec:
  capacity:
    storage: 400Gi
  accessModes:
    - ReadWriteOnce
  nfs:
    path: /volume1/server/k3s/media
    server: storage.merox.cloud
  persistentVolumeReclaimPolicy: Retain
  mountOptions:
    - hard
    - nfsvers=3
  storageClassName: ""
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jellyfin-videos
  namespace: media
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 400Gi
  volumeName: jellyfin-videos
  storageClassName: ""
```

Apply with:
```bash
kubectl apply -f nfs-media-pv-and-pvc.yaml
```

### Download Storage

Create `nfs-download-pv-and-pvc.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: qbitt-download
spec:
  capacity:
    storage: 400Gi
  accessModes:
    - ReadWriteOnce
  nfs:
    path: /volume1/server/k3s/media/download
    server: storage.merox.cloud
  persistentVolumeReclaimPolicy: Retain
  mountOptions:
    - hard
    - nfsvers=3
  storageClassName: ""
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: qbitt-download
  namespace: media
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 400Gi
  volumeName: qbitt-download
  storageClassName: ""
```

Apply with:
```bash
kubectl apply -f nfs-download-pv-and-pvc.yaml
```

## Configuring Longhorn PVC for Each Application

Create `app-config-pvc.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app # radarr for example
  namespace: media
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 5Gi
```

Apply with:
```bash
kubectl apply -f app-config-pvc.yaml
```

> This type of configuration needs to be generated for each application: Jellyfin, Sonarr, Radarr, Jackett, qBittorrent.
{: .prompt-danger }

## Deploying Each Application

### Jellyfin

Jellyfin serves as our media streaming platform, providing access to movies, TV shows, and other media across various devices.

Create `jellyfin-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jellyfin
  namespace: media
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jellyfin
  template:
    metadata:
      labels:
        app: jellyfin
    spec:
      containers:
      - name: jellyfin
        image: jellyfin/jellyfin
        volumeMounts:
        - name: config
          mountPath: /config
        - name: videos
          mountPath: /data/videos
        ports:
        - containerPort: 8096
      volumes:
      - name: config
        persistentVolumeClaim:
          claimName: jellyfin-config
      - name: videos
        persistentVolumeClaim:
          claimName: jellyfin-videos
```

Apply with:
```bash
kubectl apply -f jellyfin-deployment.yaml
```

### Sonarr

Sonarr automates TV show downloads, managing our series collection efficiently.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sonarr
  namespace: media
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sonarr
  template:
    metadata:
      labels:
        app: sonarr
    spec:
      containers:
      - name: sonarr
        image: linuxserver/sonarr
        env:
        - name: PUID
          value: "1057"
        - name: PGID
          value: "1056"
        volumeMounts:
        - name: config
          mountPath: /config
        - name: videos
          mountPath: /tv
        - name: downloads
          mountPath: /downloads
        ports:
        - containerPort: 8989
      volumes:
      - name: config
        persistentVolumeClaim:
          claimName: sonarr-config
      - name: videos
        persistentVolumeClaim:
          claimName: jellyfin-videos
      - name: downloads
        persistentVolumeClaim:
          claimName: qbitt-download
```

### Radarr

Radarr works like Sonarr but focuses on movies, keeping our film library organized and up-to-date.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: radarr
  namespace: media
spec:
  replicas: 1
  selector:
    matchLabels:
      app: radarr
  template:
    metadata:
      labels:
        app: radarr
    spec:
      containers:
      - name: radarr
        image: linuxserver/radarr
        env:
        - name: PUID
          value: "1057"  
        - name: PGID
          value: "1056"  
        volumeMounts:
        - name: config
          mountPath: /config
        - name: videos
          mountPath: /movies
        - name: downloads
          mountPath: /downloads
        ports:
        - containerPort: 7878
      volumes:
      - name: config
        persistentVolumeClaim:
          claimName: radarr-config
      - name: videos
        persistentVolumeClaim:
          claimName: jellyfin-videos
      - name: downloads
        persistentVolumeClaim:
          claimName: qbitt-download
```

### Jackett

Jackett acts as a bridge between torrent search engines and our media management tools, enhancing their capabilities.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jackett
  namespace: media
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jackett
  template:
    metadata:
      labels:
        app: jackett
    spec:
      containers:
      - name: jackett
        image: linuxserver/jackett
        env:
        - name: PUID
          value: "1057" 
        - name: PGID
          value: "1056" 
        volumeMounts:
        - name: config
          mountPath: /config
        ports:
        - containerPort: 9117
      volumes:
      - name: config
        persistentVolumeClaim:
          claimName: jackett-config
```

### qBittorrent

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: qbittorrent
  namespace: media
spec:
  replicas: 1
  selector:
    matchLabels:
      app: qbittorrent
  template:
    metadata:
      labels:
        app: qbittorrent
    spec:
      containers:
      - name: qbittorrent
        image: linuxserver/qbittorrent
        resources:
          limits:
            memory: "2Gi"
          requests:
            memory: "512Mi"
        env:
        - name: PUID
          value: "1057" 
        - name: PGID
          value: "1056"  
        volumeMounts:
        - name: config
          mountPath: /config
        - name: downloads
          mountPath: /downloads
        ports:
        - containerPort: 8080
      volumes:
      - name: config
        persistentVolumeClaim:
          claimName: qbitt-config
      - name: downloads
        persistentVolumeClaim:
          claimName: qbitt-download
```

### qBittorrent with Gluetun

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: qbittorrent
  namespace: media
spec:
  replicas: 1
  selector:
    matchLabels:
      app: qbittorrent
  template:
    metadata:
      labels:
        app: qbittorrent
    spec:
      containers:
        - name: qbittorrent
          image: linuxserver/qbittorrent
          resources:
            limits:
              memory: "2Gi"
            requests:
              memory: "512Mi"
          env:
           - name: PUID
             value: "1057"
           - name: PGID
             value: "1056"
          volumeMounts:
            - name: config
              mountPath: /config
            - name: downloads
              mountPath: /downloads
          ports:
            - containerPort: 8080

        - name: gluetun
          image: qmcgaw/gluetun
          env:
            - name: VPNSP
              value: "protonvpn"
            - name: OPENVPN_USER
              valueFrom:
                secretKeyRef:
                  name: protonvpn-secrets
                  key: PROTONVPN_USER
            - name: OPENVPN_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: protonvpn-secrets
                  key: PROTONVPN_PASSWORD
            - name: COUNTRY
              value: "Germany" 
          securityContext:
            capabilities:
              add:
                - NET_ADMIN
          volumeMounts:
            - name: gluetun-config
              mountPath: /gluetun

      volumes:
        - name: config
          persistentVolumeClaim:
            claimName: qbitt-config
        - name: downloads
          persistentVolumeClaim:
            claimName: qbitt-download
        - name: gluetun-config
          persistentVolumeClaim:
            claimName: gluetun-config
```

> I've chosen to use ProtonVPN due to their security policy and because they do not collect/store data, but also because of the speeds and diverse settings, all at a very good price.
{: .prompt-info }

## Creating ClusterIP Services

For our media server applications to communicate efficiently within the Kubernetes cluster without exposing them directly to the external network, we utilize ClusterIP services.

Create `app-service.yaml` for each app:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: app # radarr for example 
  namespace: media
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: 7878
  selector:
    app: app # radarr for example
```

Apply with:
```bash
kubectl apply -f app-service.yaml
```

## Creating Middleware for Traefik

For enhanced security and to ensure smooth functioning with Traefik, we define middleware:

Create `default-headers-media.yaml`:

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: default-headers-media
  namespace: media
spec:
  headers:
    browserXssFilter: true
    contentTypeNosniff: true
    forceSTSHeader: true
    stsIncludeSubdomains: true
    stsPreload: true
    stsSeconds: 15552000
    customFrameOptionsValue: SAMEORIGIN
    customRequestHeaders:
      X-Forwarded-Proto: https
```

Apply with:
```bash
kubectl apply -f default-headers-media.yaml
```

## Creating Ingress Route for Each Application

To expose each application securely, we create IngressRoutes using Traefik:

Create `app-ingress-route.yaml`:

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: app # radarr for example 
  namespace: media
  annotations:
    kubernetes.io/ingress.class: traefik-external
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`movies.merox.cloud`) # change to your domain
      kind: Rule
      services:
        - name: app # radarr for example 
          port: 80
    - match: Host(`movies.merox.cloud`) # change to your domain
      kind: Rule
      services:
        - name: app # radarr for example 
          port: 80
      middlewares:
        - name: default-headers-media
  tls:
    secretName: mycert-tls # change to your cert name
```

Apply with:
```bash
kubectl apply -f app-ingress-route.yaml
```

> **Don't forget**: You must create the host declared in your IngressRoute in your DNS server(s).
{: .prompt-danger }

## Q&A

**Q: Why use a ClusterIP service?**

A: Because we will be using Traefik as an ingress controller to expose it to the local network/internet with SSL/TLS certificates.

**Q: Can I download all manifest files from anywhere?**

A: SURE! The link is at the end of this page :)

## Manifest Files

Just copy and deploy all you need in no time!

[All manifest files 🔗](https://docs.merox.dev/operations/containerization/k3s/manifests/media-stack/)

---

This concludes the necessary steps and configurations to deploy a resilient media server in a Kubernetes cluster successful