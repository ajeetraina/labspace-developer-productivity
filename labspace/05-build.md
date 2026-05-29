# Lab 5 · Build

You've developed and tested your app. Now package it into an image — and watch Docker's layer caching make every rebuild after the first one fast. That speed *is* the inner-loop win.

> 📂 Run these from inside the project. If you opened a new terminal since Lab 3, `cd catalog-service-node` first.

## Step 1 · Build the image

The project ships with a `Dockerfile`. Build it and tag it as `v1.0`:

```bash
docker build -t catalog-service:v1.0 .
```

## Step 2 · List the image

Filter to just the `v1.*` tags so other images on your machine don't clutter the output:

```bash
docker images --filter "reference=catalog-service:v1.*"
```

You'll see one row — your fresh `v1.0` build.

## Step 3 · Edit a source file

Open `src/services/ProductService.js` in the IDE on the right, and add this comment at the very top of the file:

```javascript no-run-button
// here's a test file
```

**Save the file.** This is the change that'll force one layer to rebuild — everything else will come from cache.

## Step 4 · Rebuild and watch the cache work

Rebuild with a new tag:

```bash
docker build -t catalog-service:v1.1 .
```

Two things to notice in the output:

- Most steps print **`CACHED`** — Docker reused them from the v1.0 build.
- The build finishes in **seconds**, not minutes, because only the layers affected by your source edit actually re-ran. 🚀

Confirm by listing both builds:

```bash
docker images --filter "reference=catalog-service:v1.*"
```

Same size, different image IDs. The dependency layers were reused (identical size); the source-copy layer differs because of your edit (new image ID). That's the cache doing its job.

## ✅ Recap

You built an image, edited a source file, rebuilt to see layer caching cut the build to seconds, and confirmed the cache worked by comparing the two images. That tight build-edit-build loop is what makes Docker fast for everyday development. Next, you'll scan that image for vulnerabilities and fix them.

---

<details>
<summary><strong>Going deeper</strong> — Dockerfile structure, Buildx, and CI</summary>

### Why caching works: the Dockerfile's layer order

Open `Dockerfile` in the IDE (or `cat Dockerfile`). It's a **multi-stage** build with three stages — `base`, `dev`, and `final` — and the relevant pattern is the same one you'd see in any well-ordered Dockerfile:

```dockerfile no-run-button no-copy-button
# Stage: base ---------------------------------------------------------
COPY --chown=appuser:appuser package.json package-lock.json ./   # ← deps manifest only

# Stage: final --------------------------------------------------------
RUN npm ci --production --ignore-scripts && npm cache clean --force   # ← install BEFORE source
COPY ./src ./src                                                       # ← source copied AFTER
```

The dependency manifest is copied, then `npm ci` runs, *then* the source is copied. Because the install layer sits above the source layer, Docker reuses it as long as `package.json` and `package-lock.json` haven't changed — which is why your `v1.1` rebuild was instant.

### Looking at layer history

If you want to see exactly which layers got cached and how big each is:

```bash no-run-button
docker history catalog-service:v1.1
docker image inspect catalog-service:v1.1 --format '{{ .Size }}'
```

Image size matters: smaller images push, pull, and start faster — and (next lab) usually carry fewer vulnerabilities.

### Buildx and multi-platform builds

`docker buildx` is the modern build interface — it powers multi-platform builds, advanced caching, and remote builders. List your builders:

```bash no-run-button
docker buildx ls
```

Build for multiple architectures (e.g. `amd64` + `arm64`) in one command:

```bash no-run-button
docker buildx build --platform linux/amd64,linux/arm64 -t catalog-service:multiarch .
```

For large teams or heavy CI workloads, **Docker Build Cloud** offloads builds to fast, shared remote builders with a persistent cache — same `buildx` interface, different driver. Optional; not needed for this Labspace.

### Building in CI

In a real project, you'd build automatically on every push. The repo includes a **GitHub Actions** workflow that runs the same `docker build` on each commit, producing a consistent, tested artifact for the outer loop.

</details>
