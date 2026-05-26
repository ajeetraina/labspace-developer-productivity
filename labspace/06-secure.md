# Lab 6 · Secure

A working image isn't necessarily a *safe* image. In this lab you'll use **Docker Scout** to surface vulnerabilities in your image and then fix them — the security half of the inner loop, where you catch CVEs on your laptop instead of in production.

> 📂 The commands below run from inside the project directory. If you've opened a new terminal since Lab 3, `cd catalog-service-node` first.

## 🔍 What is Docker Scout?

Docker Scout analyzes your image's contents, builds a Software Bill of Materials (SBOM) of every package and dependency, and matches them against known vulnerability databases. Crucially, it doesn't just list problems — it **recommends concrete fixes**, like a newer base image or a patched dependency version.

## 🔑 Log in to Docker Hub

Docker Scout needs you to be authenticated to Docker Hub — the `quickview` and `cves` commands talk to Scout's backend, which requires a logged-in Docker account. Log in before running any Scout command:

```bash
docker login
```

Enter your own Docker Hub username and a [Personal Access Token](https://app.docker.com/settings/personal-access-tokens) (recommended over your password) when prompted. If you're already logged in, this is a no-op and you can move on.

> 🔒 Type your credentials directly into the `docker login` prompt yourself — never paste them into the lab text or a script. A Personal Access Token is safer than your password and can be revoked anytime.

Confirm Scout sees your account:

```bash
docker scout version
```

## Set up a deliberately vulnerable build

To see Scout work, we first need the image in a deliberately **vulnerable** state — an older base image and an out-of-date Express. There are two ways you might already be here:

**Check what you have first:**

```bash
grep "FROM node" Dockerfile && grep '"express"' package.json
```

- If you see an **older base** (e.g. `node:18`) and **Express `4.x`**, the vulnerable state is **already applied** — most likely the workshop's `demo/sdlc-e2e/setup.sh` prep script already ran (check with `git status`; you'll be on a `demo-…` branch with modified files). **Skip ahead to "Build the vulnerable image" below.**
- If you see `node:22-slim` and Express `5.x`, the tree is clean — apply the demo patch to create the vulnerable state:

```bash
git apply --whitespace=fix demo/sdlc-e2e/demo.patch
```

> 📂 Run from inside `catalog-service-node`. If that patch path doesn't exist, list what's available: `ls demo/*/demo.patch`. If `git apply` reports *"patch does not apply,"* the changes are already present (the prep script ran) — just continue to the build step.

**Manual fallback** (if neither the patch nor the prep script is available): open the `Dockerfile` and change the base image line to an older release, then pin an older Express in `package.json` and run `npm install`:

```dockerfile no-run-button
# Dockerfile — change the base image
FROM node:18 AS base
```

```json no-run-button
// package.json — pin an older, vulnerable Express
"express": "4.17.1",
```

## Build the vulnerable image

With the vulnerable state in place, build and tag the image:

```bash
docker build -t scout:v1.0 .
```

## Analyze the image with Scout

Get a quick vulnerability overview:

```bash
docker scout quickview scout:v1.0
```

Then dig into the detailed CVE list:

```bash
docker scout cves scout:v1.0
```

Search the output for the **Express** package. Scout flags it as out of date and tells you the minimum version that resolves the vulnerabilities — note that recommended version, you'll use it next.

## 🔧 Fix the vulnerable dependency

Open `package.json` in the editor and bump Express to the fixed version Scout recommended. For example, if it currently reads `"express": "^4.17.1"`, raise it to the latest patched 4.x release Scout suggested:

```json no-run-button
"express": "^4.21.2",
```

> 💡 Use whatever version Scout's `cves` output recommended rather than this exact number — Express releases change over time, and Scout always points you at a currently-patched version.

Reinstall dependencies so the lockfile picks up the new version:

```bash
npm install
```

Rebuild as a new tag so you can compare before and after:

```bash
docker build -t scout:v2.0 .
```

## ✅ Verify the fix

Re-scan the new image:

```bash
docker scout cves scout:v2.0
```

You'll notice the **High (H)** and **Critical (C)** vulnerabilities tied to the old Express version are gone. 🎉

## Compare the two images directly

One of Scout's most useful features is a side-by-side comparison. See exactly what changed between your vulnerable and fixed builds:

```bash
docker scout compare scout:v2.0 --to scout:v1.0
```

This is the kind of evidence you can drop straight into a pull request: "this change removes N critical and M high CVEs."

## 💡 Two approaches to image security

- **Reactive** — scan images you've already built (what you just did with Scout) and remediate findings. Great for catching regressions and continuously monitoring images you ship.
- **Proactive** — start from a minimal, already-hardened base so there's far less to fix in the first place. This is the idea behind **Docker Hardened Images (DHI)** — slim, secure-by-default base images with built-in attestations.

The strongest workflow combines both: build on a hardened base, *and* keep scanning with Scout so new CVEs in your dependencies never slip through.

## ✅ Recap

You introduced known vulnerabilities, found them with Docker Scout, fixed a vulnerable Express dependency, and verified the High and Critical CVEs were eliminated — then compared the two images to prove it. That completes the core inner-loop lifecycle: **develop → test → build → secure**.

Next, we shift gears and add **local AI** to the catalog service. 🤖
