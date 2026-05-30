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

After Lab 5 you have `catalog-service:v1.1` from the `node:18` base. Let's measure the cost.

Quick vulnerability overview:

```bash
docker scout quickview catalog-service:v1.1
```

Expected output (approximate):

```none no-copy-button
  Target             │  catalog-service:v1.1  │    2C    26H    25M   122L     4?
    digest           │  360db4f00cbd          │
  Base image         │  node:18               │    2C    26H    25M   122L     4?
  Updated base image │  node:25-slim          │    0C     1H     2M    24L
                     │                        │    -2    -25    -23    -98     -4
```

Scout is already pointing at the answer: one `FROM` line change eliminates
**2 critical and 25 high** CVEs immediately.

Now the policy view:

```bash
docker scout policy catalog-service:v1.1
```

```none no-copy-button
Policy status  FAILED  (4/7 policies met)

  Status │                     Policy                     │           Results
─────────┼────────────────────────────────────────────────┼──────────────────────────────
  ✓      │ Default non-root user                          │
  !      │ AGPL v3 licenses found                         │    3 packages
  !      │ Fixable critical or high vulnerabilities found │    2C    26H     0M     0L
  ✓      │ No high-profile vulnerabilities                │
  ✓      │ No outdated base images                        │
  !      │ Unapproved base images found                   │    1 deviation
  ✓      │ Supply chain attestations                      │    0 deviations
```

4/7 policies failing. This is the **reactive "scan and fix" cycle** — developers
spend three days researching fixes, rebuild, still have 189 vulnerabilities
remaining, cycle repeats, security blocks deployment.

Let's fix this proactively, one best practice at a time.

---

## Demo #2 · BP#1 — Minimal base images

> **Less OS surface = fewer CVEs = smaller attack window.**

The comparison at a glance:

| Image | Size | Packages | CVEs |
|-------|------|----------|------|
| `node:25` (full) | 1.63 GB | 693 | 242 |
| `node:lts-slim` | 344 MB | ~272 | 34 |
| `node:25-slim` | 322 MB | 272 | 30 |
| `node:alpine` | 239 MB | ~150 | 34 |

Open `catalog-service-node/Dockerfile` in the IDE on the right, and change line 8 — the `base` stage's `FROM`:

```diff no-run-button no-copy-button
- FROM node:18 AS base
+ FROM node:25-slim AS base
```

Save the file. Then rebuild and re-scan:

```bash
docker build -t catalog-service:slim --sbom=true --provenance=mode=max .
```

```bash
docker images --filter "reference=catalog-service"
```

```none no-copy-button
IMAGE                    ID             DISK USAGE   CONTENT SIZE
catalog-service:v1.0     48806e62b871       1.62GB          413MB
catalog-service:v1.1     d56cedd39a9a       1.62GB          413MB
catalog-service:slim     8d03cef7a79f        368MB         84.1MB
```

```bash
docker scout quickview catalog-service:slim
```

```none no-copy-button
  Target             │  catalog-service:slim  │    0C     2H     2M    24L
  Base image         │  node:25-slim          │    0C     1H     2M    24L
```

One `FROM` change: **2 critical eliminated, 25 high eliminated, image 4× smaller.**

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
FROM node:25-slim AS base     ← shared foundation
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

You watched a real app go from **2 critical and 26 high CVEs on the `node:18` base** to a smaller, hardened image with the critical and high vulnerabilities eliminated — without changing a line of application code. Then you ran that image with the runtime hardened: non-root, read-only filesystem, dropped capabilities. And you saw how to bake continuous scanning into CI so the same posture holds for every commit.

Five practices, one app, measurable wins each time.

> 🚀 **What's next** — there are three more security best practices and a full **Docker Hardened Images (DHI)** migration story (signed SBOMs, VEX, FIPS, SLSA provenance) covered in the dedicated *Container Security* labspace at [github.com/ajeetraina/labspace-container-security](https://github.com/ajeetraina/labspace-container-security). If this lab clicked, that's where you go deeper.
