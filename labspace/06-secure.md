# Lab 6 · Secure

> **The four attack vectors that keep production teams up at night:**
> Image Vulnerabilities · Supply Chain Integrity · Runtime Attack Surface · Compliance

You've built and tagged a working image. Now make it production-ready: surface its
vulnerabilities and shrink the attack surface through **five container security
best practices**. Each one is a real, measurable improvement — by the end of the
lab the same app ships with a fraction of the CVEs, a fraction of the size, and
a fraction of the privileges.

> 📂 Run these from inside the project. If you opened a new terminal since Lab 3, `cd catalog-service-node` first. Some commands also use Docker Scout, which requires a Docker Hub login — run `docker login` once before the first `docker scout` command.

---

## Demo #1 · Surface the problem

After Lab 5 you have `catalog-service:v1.1`. If you followed Lab 3's `setup.sh` step, the Dockerfile was patched to `FROM node:18` — a deliberately old base that gives us a realistic "legacy app" starting point. Let's measure where it stands.

Quick vulnerability overview:

```bash
docker scout quickview catalog-service:v1.1
```

Your output will look something like this:

```none no-copy-button
 Target             │  catalog-service:v1.1  │    3C   111H   131M   233L    20?
   digest           │  377cfda812cc          │
 Base image         │  node:18               │    3C   110H   128M   233L    20?
 Updated base image │  node:26-slim          │    1C     4H     5M    23L
                    │                        │    -2   -106   -123   -210    -20
```

That bottom row is the punchline. By **just changing one `FROM` line** — `node:18` → `node:26-slim` — you'd eliminate **2 critical, 106 high, 123 medium, 210 low** vulnerabilities. No code changes, no rebuilds beyond the new base, no waiting for upstream fixes.

> 💡 The exact CVE counts will drift over time — new vulnerabilities are disclosed daily against `node:18`. The relative shape (huge CVE count on the old base → small one on slim) is the durable lesson.

Now the policy view:

```bash
docker scout policy catalog-service:v1.1
```

```none no-copy-button
Policy status  FAILED  (1/7 policies met, 2 missing data)

 Status │                     Policy                     │           Results
────────┼────────────────────────────────────────────────┼─────────────────────────────
 ✓      │ Default non-root user                          │
 !      │ AGPL v3 licenses found                         │    4 packages
 !      │ Fixable critical or high vulnerabilities found │    2C    92H     0M     0L
 !      │ High-profile vulnerabilities found             │    0C     1H     0M     0L
 ?      │ No outdated base images                        │    No data
 ?      │ No unapproved base images                      │    No data
 !      │ Missing supply chain attestation(s)            │    1 deviation
```

Only **1 of 7 policies passing.** The image has a high-profile CVE, 92 fixable highs, AGPL v3 licenses, and is missing supply-chain attestations.

Scroll down in the same `docker scout policy` output and you'll see Scout drill into each failing policy — naming exact packages and the **exact fix version** for every CVE. For example:

```none no-copy-button
## "No fixable critical or high vulnerabilities" policy evaluation results

 Vulnerability  │  Severity  │  Current package version          │  Fix version
────────────────┼────────────┼───────────────────────────────────┼──────────────────────
 CVE-2025-49796 │  CRITICAL  │ libxml2@2.9.14+dfsg-1.3~deb12u1   │ 2.9.14+dfsg-1.3~deb12u3
 CVE-2025-49794 │  CRITICAL  │ libxml2@2.9.14+dfsg-1.3~deb12u1   │ 2.9.14+dfsg-1.3~deb12u3
 CVE-2024-21538 │    HIGH    │ cross-spawn@7.0.3                 │ 7.0.5
 CVE-2025-64756 │    HIGH    │ glob@10.4.2                       │ 11.1.0
 ...
```

That's actionable signal, not noise — it's a **fix list**, not just a verdict. But trying to patch 92 individual packages would be a multi-day slog. This is the **reactive "scan and fix" trap**: developers spend three days researching individual CVEs, rebuild, find another wave waiting, security blocks deployment.

Let's fix it proactively, one best practice at a time.

---

## Demo #2 · BP#1 — Minimal base images

> **Less OS surface = fewer CVEs = smaller attack window.**

Scout already showed you the upgrade path in Demo #1 — `node:18` → `node:26-slim` eliminates **2 critical and 106 high** CVEs. Let's do the swap and see it for real.

Open `catalog-service-node/Dockerfile` in the IDE on the right and change line 8 (the `base` stage's `FROM`):

```diff no-run-button no-copy-button
- FROM node:18 AS base
+ FROM node:26-slim AS base
```

Save the file. Then rebuild with a new tag:

```bash
docker build -t catalog-service:slim .
```

List your images side by side:

```bash
docker images --filter "reference=catalog-service"
```

Expected — `slim` is dramatically smaller:

```none no-copy-button
IMAGE                    ID             DISK USAGE   CONTENT SIZE
catalog-service:v1.0     48806e62b871       1.62GB          413MB
catalog-service:v1.1     d56cedd39a9a       1.62GB          413MB
catalog-service:slim     8d03cef7a79f        368MB         ~85MB
```

Now rescan:

```bash
docker scout quickview catalog-service:slim
```

```none no-copy-button
  Target             │  catalog-service:slim  │    0C     2H     2M    24L
  Base image         │  node:26-slim          │    0C     1H     2M    24L
```

**Zero critical. Two high.** From `3C / 110H / 128M / 233L` down to `0C / 2H / 2M / 24L` with a one-line `FROM` change. Image is ~4× smaller. Same app, same code, fundamentally different security posture.

The comparison at a glance (these numbers drift as new CVEs are disclosed, but the *shape* is consistent):

| Image | Approx. size | Approx. packages | Approx. CVEs |
|-------|--------------|------------------|--------------|
| `node:18` (legacy full) | 940 MB | 700+ | 380+ |
| `node:26` (current full) | 1.1 GB | 690+ | 200+ |
| `node:26-slim` | 240 MB | 270 | 30-50 |
| `node:26-alpine` | 220 MB | 150 | 30-40 |

> 💡 **Want to push further?** Distroless and Docker Hardened Images (DHI) take this idea to its logical end — sometimes a single application binary with no shell, no package manager, no OS. Out of scope here; covered in the dedicated [container-security labspace](https://github.com/ajeetraina/labspace-container-security).

---

## Demo #3 · BP#2 — Multi-stage builds

> **Dev tools, compilers, and test frameworks stay out of production.**

### What must NOT ship to production

- Source code (after copy/compile)
- IDE tooling and editors
- Compilers and build tools
- Debuggers
- `npm install` full set (includes devDependencies)
- Non-deployable build artifacts

### Examine the Dockerfile structure

Open `catalog-service-node/Dockerfile`. It already uses three stages:

```none no-copy-button
FROM node:26-slim AS base     ← shared foundation
  └─ FROM base AS dev          ← installs ALL deps + dev tools
  └─ FROM base AS final        ← npm ci --production only
```

The critical production line:

```dockerfile no-run-button no-copy-button
RUN npm ci --production --ignore-scripts && npm cache clean --force
```

- `--production` — only production dependencies, devDeps excluded
- `--ignore-scripts` — no post-install scripts (a common supply chain attack vector)
- `npm cache clean --force` — removes cache from the layer, shrinks image

### Build specific stages

Dev stage only:

```bash
docker build -t catalog-service:dev --target dev .
```

Production stage only:

```bash
docker build -t catalog-service:prod --target final .
```

```bash
docker images --filter "reference=catalog-service"
```

The `dev` image is larger (all devDependencies). The `prod` image is lean —
smaller attack surface, faster pulls.

### Why `--ignore-scripts` matters

```bash
docker scout cves catalog-service:prod --only-severity critical,high
```

Post-install scripts are a well-known supply chain attack vector (the `node-ipc`
incident in 2022 exploited this). `--ignore-scripts` prevents them from running
during `npm ci`.

---

## Demo #4 · BP#3 — Non-root user

> **Root inside a container is effectively root on the host if isolation fails.**

By default, Docker containers run as `root` (UID 0). If an attacker exploits your
app, they get root-level access inside the container — and potentially on the host
if the container is misconfigured or running with a privileged socket.

### Three ways to enforce non-root

**Option A — In the Dockerfile (recommended, what we already have).** Open `catalog-service-node/Dockerfile` and look at line 12:

```dockerfile no-run-button no-copy-button
RUN useradd -m appuser && chown -R appuser /usr/local/app
USER appuser
```

**Option B — At `docker run` time:**

```bash
docker run --rm --user 1000:1000 catalog-service:slim \
    node -e "console.log(process.getuid())"
```

Expected output: `1000` — not `0`.

**Option C — In `docker compose`:**

```yaml no-run-button no-copy-button
services:
  catalog:
    build: .
    user: "${CURRENT_UID}"
```

### Verify the running user

```bash
docker run --rm catalog-service:slim whoami
```

Expected: `appuser` — not `root`.

### The hardened `docker init` pattern

When you run `docker init` in a new project, Docker scaffolds this automatically:

```dockerfile no-run-button no-copy-button
ARG UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    appuser
USER appuser
```

Extra hardening: no home directory, no login shell, no password — minimal footprint.

### Confirm Scout policy

```bash
docker scout quickview catalog-service:slim
```

Look for `Default non-root user` — should show ✓.

---

## Demo #5 · BP#4 — Read-only filesystem + drop Linux capabilities

> **Even if an attacker gains code execution, a read-only container with dropped capabilities severely limits what they can do next.**

### Linux capabilities — what gets dropped with `--cap-drop=ALL`

| Capability | What it allows |
|------------|----------------|
| `CHOWN` | Change file UIDs/GIDs |
| `DAC_OVERRIDE` | Bypass file read/write/execute permission checks |
| `NET_RAW` | Raw and packet sockets (used in some network attacks) |
| `SETUID` / `SETGID` | Change process UID/GID |
| `SYS_CHROOT` | `chroot()` — change root directory |
| `KILL` | Send signals to other processes |
| `MKNOD` | Create special files |

### Step 1 · Clean up any leftover containers

Run this first. It removes any containers from a previous attempt so names and ports are free:

```bash
docker rm -f catalog-hardened catalog-hardened-tmpfs 2>/dev/null; echo "clean"
```

### Step 2 · Run with hardened flags

```bash
docker run \
    -d \
    -p 3100:3000 \
    --read-only \
    --cap-drop=ALL \
    --user=65532 \
    --name catalog-hardened \
    catalog-service:slim
```

```bash
docker ps --filter name=catalog-hardened
```

```bash
curl http://localhost:3100
```

### Step 3 · Verify the filesystem is read-only

```bash
docker exec catalog-hardened sh -c "echo test > /tmp/test.txt"
```

Expected: `sh: /tmp/test.txt: Read-only file system`

The attacker gained code execution but **cannot write anywhere** — no dropping
payloads, no modifying config files, no creating SUID binaries.

### Step 4 · Prove the capability drop

```bash
docker inspect catalog-hardened \
    --format 'ReadonlyRootfs={{.HostConfig.ReadonlyRootfs}} CapDrop={{.HostConfig.CapDrop}}'
```

Expected:

```none no-copy-button
ReadonlyRootfs=true CapDrop=[ALL]
```

### Step 5 · When your app needs a writable area — use `tmpfs`

`tmpfs` is in-memory only — writable but never persisted to disk, gone when the
container stops:

```bash
docker run \
    -d \
    -p 3101:3000 \
    --read-only \
    --tmpfs /tmp:noexec,nosuid,size=64m \
    --cap-drop=ALL \
    --user=65532 \
    --name catalog-hardened-tmpfs \
    catalog-service:slim
```

```bash
docker exec catalog-hardened-tmpfs sh -c "echo test > /tmp/test.txt && cat /tmp/test.txt"
```

`/tmp` is writable in memory. Everything else is still read-only.

The extra `tmpfs` flags matter:
- `noexec` — files in `/tmp` cannot be executed
- `nosuid` — SUID bits on files in `/tmp` are ignored
- `size=64m` — caps memory usage to 64 MB

### Step 6 · Clean up

```bash
docker rm -f catalog-hardened catalog-hardened-tmpfs
```

---

## Demo #6 · BP#5 — Scan continuously, not just at build

> **New CVEs are disclosed every day against images you built months ago.**
> Scanning must happen throughout the entire SDLC — at code, build, registry push, and in production.

### The three Scout commands you'll actually use

**Quickview — fast summary:**

```bash
docker scout quickview catalog-service:slim
```

**CVE drill-down — critical and high only:**

```bash
docker scout cves catalog-service:slim --only-severity critical,high
```

**Compare — see exactly what changed between two images:**

```bash
docker scout compare \
    --ignore-unchanged \
    --to catalog-service:v1.1 \
    catalog-service:slim
```

The `compare` output shows exactly which packages were added/removed/changed and
which CVEs were introduced or eliminated — actionable signal, not just noise.

### Recommendations — base image upgrade path

```bash
docker scout recommendations catalog-service:slim
```

Scout shows the exact upgrade tag that resolves remaining CVEs, along with how many
vulnerabilities each candidate eliminates.

### Integrate Scout into CI

The repo includes a GitHub Actions workflow at `catalog-service-node/.github/workflows/pipeline-docker-cloud.yaml` that runs Scout on every build. The key gate step:

```yaml no-run-button no-copy-button
- name: Docker Scout CVEs
  uses: docker/scout-action@v1
  with:
    command: cves
    image: ${{ steps.build.outputs.imageid }}
    only-severities: critical,high
    exit-code: true
```

`exit-code: true` makes the pipeline **fail** if critical or high CVEs are found —
the gate that prevents vulnerable images from reaching production.

### Background SBOM indexing in Docker Desktop

Enable via **Settings → General → Enable background Scout SBOM indexing**.

Scout continuously analyses every image you pull or build — you get alerts before
you even think to scan.

---

## ✅ Recap

You watched a real app go from **3 critical and 110 high CVEs on the `node:18` base** down to **0 critical and 2 high** on the slim image — without changing a line of application code. Then you ran that image with the runtime hardened: non-root, read-only filesystem, dropped capabilities. And you saw how to bake continuous scanning into CI so the same posture holds for every commit.

Five practices, one app, measurable wins each time.

> 🚀 **What's next** — there are three more security best practices and a full **Docker Hardened Images (DHI)** migration story (signed SBOMs, VEX, FIPS, SLSA provenance) covered in the dedicated *Container Security* labspace at [github.com/ajeetraina/labspace-container-security](https://github.com/ajeetraina/labspace-container-security). If this lab clicked, that's where you go deeper.
