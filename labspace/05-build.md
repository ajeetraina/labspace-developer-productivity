# Lab 5 · Build

With your code developed and tested, it's time to package it into a container image. This lab focuses on **building locally** with Docker and BuildKit — no cloud builder required.

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

The single biggest inner-loop win when building is **layer caching**. Because Docker caches each instruction's result, dependencies only get re-installed when the files that affect them actually change.

This is why a well-ordered `Dockerfile` copies and installs dependencies *before* copying application source:

```dockerfile no-run-button
# Dependencies change rarely → cache this layer
COPY package.json package-lock.json ./
RUN npm install --omit=dev

# Source changes often → put it after the dependency layer
COPY . .
```

Try it: build once, then change a source file and build again. The dependency-install step is served from cache, so the second build is dramatically faster:

```bash
docker build -t catalog-service:v1.1 .
```

You'll see `CACHED` next to the dependency layers in the build output. 🚀

## Inspect what you built

Check the image's layer history and size:

```bash
docker history catalog-service:v1.0
```

```bash
docker image inspect catalog-service:v1.0 --format '{{ .Size }}'
```

Keeping an eye on image size matters: smaller images push, pull, and start faster — and (as you'll see in the next lab) usually carry fewer vulnerabilities.

## Run your freshly built image

Give it a spin to confirm it actually runs:

```bash
docker run --rm -p 3000:3000 catalog-service:v1.0
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
