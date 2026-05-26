# Lab 6 · Secure

A working image isn't necessarily a *safe* image. In this lab you'll use **Docker Scout** to surface vulnerabilities in your image and then fix them — the security half of the inner loop, where you catch CVEs on your laptop instead of in production.

## 🔍 What is Docker Scout?

Docker Scout analyzes your image's contents, builds a Software Bill of Materials (SBOM) of every package and dependency, and matches them against known vulnerability databases. Crucially, it doesn't just list problems — it **recommends concrete fixes**, like a newer base image or a patched dependency version.

## Set up a deliberately vulnerable build

To see Scout work, we'll first introduce some known issues. This patch adjusts the `Dockerfile` to use an **older base image** and installs an **older, vulnerable version of Express** — perfect for demonstrating out-of-date base images and vulnerable dependencies:

```bash
git apply --whitespace=fix demo/scout.patch
```

Now build the (intentionally vulnerable) image:

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

Search the output for the **Express** package. Scout will flag it and tell you the fix is available in **express 4.17.3+**.

## 🔧 Fix the vulnerable dependency

Open `package.json` in the editor and change the Express version from `4.17.3` to `4.19.2`:

```json no-run-button
"express": "4.19.2"
```

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
