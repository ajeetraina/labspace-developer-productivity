# Lab 5 · Build

With your code developed and tested, it's time to package it into a container image. This lab focuses on **building locally** with Docker and BuildKit — no cloud builder required.

> 📂 The commands below run from inside the project directory. If you've opened a new terminal since Lab 3, `cd catalog-service-node` first.

## Build the image

The project ships with a `Dockerfile`. Build it and give it a tag:

```bash
docker build -t catalog-service:v1.0 .
```

BuildKit (the default builder) runs each instruction, caches the layers, and produces a tagged image. List it:

```bash
docker images catalog-service
```

## Make builds faster with layer caching

The single biggest inner-loop win when building is **layer caching**. Docker caches each instruction's result, so dependencies only get re-installed when the files that affect them actually change.

Take a look at the project's `Dockerfile` — **open it in the IDE on the right** (`catalog-service-node/Dockerfile`). You can also print it inline:

```bash
cat Dockerfile
```

It's a **multi-stage build** with three stages — `base`, `dev`, and `final` — but the layer-caching principle is the same one you'd see in any well-ordered Dockerfile. Look at what each relevant stage does:

```dockerfile no-run-button no-copy-button
# --- Stage: base -----------------------------------------------------
FROM node:18 AS base
WORKDIR /usr/local/app
RUN useradd -m appuser && chown -R appuser /usr/local/app
USER appuser
COPY --chown=appuser:appuser package.json package-lock.json ./   # ← deps manifest only

# --- Stage: final ----------------------------------------------------
FROM base AS final
ENV NODE_ENV production
RUN npm ci --production --ignore-scripts && npm cache clean --force   # ← install BEFORE source
COPY ./src ./src                                                       # ← source copied AFTER
```

Notice the order across the two stages:

1. The **dependency manifest** (`package.json`, `package-lock.json`) is copied in the `base` stage.
2. The **install step** (`npm ci`) runs in `final`, *before* any source code is brought in.
3. The **source** (`./src`) is copied *last*.

That ordering is what makes caching work: Docker can reuse the `npm ci` layer as long as the two manifest files haven't changed — even when you edit source code. Splitting it across `base` and `final` also lets the separate `dev` stage reuse the same dependency setup without duplicating it.

Try it: open `src/services/ProductService.js` in the IDE and add a comment at the very top of the file:

```javascript no-run-button
// here's a test file
```

Save the file, then rebuild with a new tag:

```bash
docker build -t catalog-service:v1.1 .
```

You'll see `CACHED` next to the dependency-install layers in the output — only the source-copy and downstream layers actually re-run. The second build is dramatically faster. 🚀

## Inspect what you built

Check the latest image's layer history and size:

```bash
docker history catalog-service:v1.1
```

```bash
docker image inspect catalog-service:v1.1 --format '{{ .Size }}'
```

You can also see both builds side by side and confirm they're almost identical — same layers up to the source-copy step, where `v1.1` diverges because that's the only layer that wasn't cached:

```bash
docker images catalog-service
```

```bash
diff <(docker history --no-trunc catalog-service:v1.0) <(docker history --no-trunc catalog-service:v1.1)
```

Most rows will match exactly. The only difference is the source-copy layer (and anything that depends on it) — concrete proof that everything *above* it was reused from cache.

Keeping an eye on image size matters: smaller images push, pull, and start faster — and (as you'll see in the next lab) usually carry fewer vulnerabilities.

## Run your freshly built image

Give it a spin to confirm it actually runs:

```bash
docker run --rm -p 3000:3000 catalog-service:v1.1
```

## Building with Buildx

`docker buildx` is the extended build interface that powers multi-platform builds, advanced caching, and remote builders. Even locally, it's the modern default. List your builders:

```bash
docker buildx ls
```

Build a multi-architecture image (for example `amd64` + `arm64`) in one command:

```bash no-run-button
docker buildx build --platform linux/amd64,linux/arm64 -t catalog-service:multiarch .
```

> 💡 **Optional — scaling out builds.** For large teams or heavy CI workloads, **Docker Build Cloud** lets you offload builds to fast, shared remote builders with a persistent cache. It's the same `buildx` interface — you just target a `--driver cloud` builder instead of your local one. It's entirely optional and not needed for this Labspace; everything here builds locally.

## Building in CI

In a real project, you'd build automatically on every push. The repo includes a **GitHub Actions** workflow that builds the image as part of the outer loop — the same `docker build` you ran here, triggered on each commit, so every change produces a consistent, tested artifact.

## ✅ Recap

You built the application image locally, saw how layer caching speeds up repeated builds, inspected the result, ran it, and learned how Buildx scales to multi-platform and CI builds. Next, you'll scan that image for vulnerabilities and fix them.
