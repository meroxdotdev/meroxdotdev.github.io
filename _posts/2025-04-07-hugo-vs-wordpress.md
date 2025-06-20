---
title: "From WordPress to Hugo: My Setup Explained"
date: 2025-04-07 10:00:00 +0200
categories: [infrastructure]
tags: [wordpress, hugo, github-actions, github-pages, cloudflare, static-site, website-setup, migration]
description: Why I migrated from WordPress to Hugo, pros and cons of both platforms, and a detailed look into how my website runs today using GitHub Actions, GitHub Pages, and Cloudflare.
image:
  path: /assets/img/posts/wordpress-to-hugo-banner.webp
  alt: WordPress to Hugo Migration Guide
---

Ten years ago, I started my first website projects—some for myself, others for friends or clients. I spent a lot of time experimenting with themes, plugins, and WordPress setups.

##  My Experience with WordPress

WordPress is a solid way to get started—especially if you're messing around with your first LAMP server. But long term? It can be a pain. You'll find yourself tweaking PHP configs, switching to LiteSpeed, juggling plugin updates, and basically fine-tuning everything so it doesn't fall apart.

### What I Liked

- Database-based structure  
- Huge plugin ecosystem  
- Easy integrations with third-party tools  
- Pretty smooth for non-devs thanks to the admin dashboard

### But Also...

- Every plugin is another potential vulnerability  
- Too many resources for something like a static website  
- Gets heavy fast (plugins + DB = bottleneck)  
- Needs constant updates and babysitting

From my perspective, if you just want a simple presentation website, WordPress is overkill. You're burning CPU cycles and adding surface area for no real reason.

E-commerce? Maybe. WooCommerce is fine—until it isn't. Do your research. Shopify is probably the better call long-term.

Here's a visual from [wpscan.com](https://wpscan.com) showing the current number of known vulnerabilities:

![WordPress Vulnerabilities](/assets/img/posts/wpscan-vuln-statistics.png){: width="700" height="400" }
_WordPress vulnerability statistics from WPScan_

## Moving to Hugo

For over 6 months now, I've been all-in on Hugo—my current site [merox.dev](https://merox.dev) runs entirely on it. I had totally underestimated the power of a static site. Hugo's written in Go, builds super fast, and is already SEO-optimized out of the box.

![Hugo Website](/assets/img/posts/hugo-website.png){: width="700" height="400" }
_Hugo static site generator homepage_

I chose [Blowfish](https://blowfish.page/) as the theme and tweaked it over time to fit my needs.

### Hugo Pros

- Static = zero backend vuln headaches  
- Hosting? Free, thanks to GitHub Pages  
- Markdown = clean, portable, fast to edit  
- Insanely fast loading  
- Version control with Git, so I always know what's changing

### Hugo Cons

- You need to be a bit technical  
- No dashboard—everything's in Markdown  
- Some DevOps skills help if you want a clean, automated setup

## Setting Up Hugo + Blowfish

1. Install Hugo: [https://gohugo.io/installation/](https://gohugo.io/installation/)  
2. Add Blowfish theme: [https://blowfish.page/docs/installation/](https://blowfish.page/docs/installation/)  
3. Use `blowfish-tools` for live previews—it's a nice touch

To keep the theme up to date without breaking my customizations, I forked Blowfish and added it as a Git submodule like this:

```bash
git submodule add https://github.com/YOURUSERNAME/blowfish themes/blowfish
```

This way, I can track upstream updates while maintaining my own style.

## Connecting Domain via GitHub Pages + Cloudflare

After installing Hugo + Blowfish, I decided to host my site using GitHub Pages and manage DNS via Cloudflare.

Here's a quick guide:

1. Push Hugo project to a **private** repo  
2. Enable GitHub Pages on a **public** repo (choose branch: `gh-pages`, folder: `/`)  
3. In Cloudflare:  
   - Add a **CNAME** for `www.yourdomain.com` → `yourusername.github.io`  
   - Add **A records** pointing to GitHub Pages IPs if needed  
4. Add a `CNAME` file in your repo containing:  
   ```
   merox.dev
   ```

Wait for DNS to propagate and you're done.

![GitHub Pages Setup](/assets/img/posts/github-pages.png){: width="700" height="400" }
_GitHub Pages configuration interface_

## Automating Deploys with GitHub Actions

I'm not about that manual deploy life. So I set up GitHub Actions to take care of builds and deploys whenever I push to `master`.

My workflow? Make changes in VS Code → push to private repo → GitHub Actions builds → deploys to public repo.

## Connecting Private + Public Repo Using RSA

I didn't want my source repo to be public. So here's how I did the private → public deploy using RSA keys:

### SSH Deploy Setup

1. Generate an RSA key pair:

```bash
ssh-keygen -t rsa -b 4096 -C "github-deploy" -f deploy_key -N ""
```

2. Public repo (destination):  
   - Go to Settings → Deploy Keys → Add `deploy_key.pub` with write access

3. Private repo (source):  
   - Settings → Secrets → Add `PRIVATE_KEY` → paste the private key contents

4. My `.github/workflows/deploy.yml`:

```yaml
name: github pages

on:
  push:
    branches:
      - master

permissions:
  contents: write
  id-token: write

jobs:
  deploy:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: true
          fetch-depth: 0

      - name: Setup Hugo
        uses: peaceiris/actions-hugo@v3
        with:
          hugo-version: 'latest'
          extended: true

      - name: Build
        run: hugo --minify

      - name: Deploy
        uses: peaceiris/actions-gh-pages@v3
        with:
          deploy_key: ${{ secrets.PRIVATE_KEY }}
          external_repository: meroxdotdev/merox.dev
          publish_branch: gh-pages
          publish_dir: ./public
```

![GitHub Actions Workflow](/assets/img/posts/github-actions.png){: width="700" height="400" }
_GitHub Actions workflow in action_

## SEO Results After the Switch

I didn't even have to do much SEO magic — Hugo just works. With clean structure and no bloat, I got over 80% SEO scores right away. That's the beauty of static sites done right.

![SEO Score Analysis 1](/assets/img/posts/seochecker.png){: width="700" height="400" }
_SEO analysis from freetools.seobility.net_

From [https://freetools.seobility.net/](https://freetools.seobility.net/)

![SEO Score Analysis 2](/assets/img/posts/seocheckup.png){: width="700" height="400" }
_SEO checkup results from seositecheckup.com_

From [https://seositecheckup.com/](https://seositecheckup.com/)

## Final Thoughts

No more updates every week. No plugin bugs. No servers to worry about. And I finally get a blazing-fast site, version-controlled, with everything set up exactly how I want.

If you're into the idea of a static site and want help setting one up—or just have questions—drop me an email or comment. Happy to help.