# Introduction

👋 Welcome to the **Docker Developer Productivity** Labspace!

This lab walks you through the complete **inner-loop developer workflow** with Docker — the tight, iterative cycle of *write → build → run → test → debug* that you repeat dozens of times a day before your code ever leaves your machine. You'll start with the basics of running containers, then work through a real-world **Product Catalog** application across its whole lifecycle, and finish by adding **local AI** capabilities with Docker Model Runner and the MCP Gateway.

## 🔁 Inner loop vs. outer loop

The **inner loop** is the iterative process of writing, building, and debugging code that a single developer performs *before* sharing it with the team. It's characterized by frequent, fast changes as you learn more about the problem you're solving.

The **outer loop** is everything else leading up to release — code merge, automated review, test execution, deployment, controlled rollout, and observation. It changes less frequently because the focus is on stability and production-readiness.

The inner loop maps to the **development** phase of the SDLC; the outer loop maps to **testing, deployment, and release**. The two aren't mutually exclusive — they overlap — and Docker is what makes the handoff between them smooth.

This Labspace lives mostly in the inner loop, but every lab is designed so the same workflow scales cleanly into the outer loop.

## 🎯 What you'll learn

- Running and inspecting multiple containers (starting with Postgres)
- The architecture of a realistic, multi-service application
- Developing against a fully containerized environment with live reload
- Integration testing with Testcontainers
- Building images efficiently
- Finding and fixing vulnerabilities with Docker Scout
- Running local LLMs with Docker Model Runner
- Orchestrating AI tools through the Docker MCP Gateway

## 📦 What you'll build

The centerpiece is the **Catalog Service** — a Node.js API backed by:

- **PostgreSQL** for product data
- **AWS S3** (via LocalStack locally) for product images
- An external **inventory service** (mocked with WireMock locally)
- **Kafka** for publishing product update events

By the end, you'll have extended this same service with a conversational AI chatbot and a multi-agent evaluation system — all running locally in containers.

## ✅ Prerequisites

- Basic understanding of Docker concepts
- Familiarity with Node.js development
- Comfort with a terminal / command line

Everything you need is already running in this Labspace environment — there's nothing to install on your own machine.

Let's get started! 🚀
