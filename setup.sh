#!/usr/bin/env bash
#
# setup-labspace.sh
#
# Populates an ajeetraina/labspace-developer-productivity clone with the
# "Docker Developer Productivity - Inner Loop to AI" Labspace content.
#
# Usage:
#   ./setup-labspace.sh           # run from the root of your cloned repo
#   ./setup-labspace.sh /path/to/labspace-developer-productivity
#
# Safe to re-run: existing files are backed up to ./.labspace-backup-<timestamp>/
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve target repo directory
# ---------------------------------------------------------------------------
REPO_DIR="${1:-$PWD}"

if [ ! -d "$REPO_DIR" ]; then
  echo "ERROR: target directory does not exist: $REPO_DIR" >&2
  exit 1
fi

cd "$REPO_DIR"

# Sanity check: looks like the labspace starter?
if [ ! -d "labspace" ] && [ ! -f "compose.yaml" ]; then
  echo "WARNING: '$REPO_DIR' doesn't look like a labspace repo" >&2
  echo "         (no ./labspace dir and no ./compose.yaml found)." >&2
  printf "Continue anyway? [y/N] "
  read -r ans
  case "$ans" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

echo "==> Target repo: $REPO_DIR"

# ---------------------------------------------------------------------------
# Back up anything we are about to replace
# ---------------------------------------------------------------------------
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR=".labspace-backup-$TS"

backup() {
  # $1 = path relative to repo root
  if [ -e "$1" ]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$1")"
    cp -a "$1" "$BACKUP_DIR/$1"
  fi
}

echo "==> Backing up existing files to ./$BACKUP_DIR/ (if any)"
backup "compose.override.yaml"
# Back up the starter's default section files
for f in labspace/01-introduction.md labspace/02-main-content.md labspace/03-conclusion.md labspace/labspace.yaml; do
  backup "$f"
done

# ---------------------------------------------------------------------------
# Remove the starter's default section markdown (keep a backup above)
# ---------------------------------------------------------------------------
echo "==> Removing starter placeholder sections"
rm -f labspace/01-introduction.md labspace/02-main-content.md labspace/03-conclusion.md

mkdir -p labspace

# ---------------------------------------------------------------------------
# Write the new Labspace files
# ---------------------------------------------------------------------------
echo "==> Writing Labspace content"

echo "    - labspace/labspace.yaml"
cat > 'labspace/labspace.yaml' <<'LABSPACE_EOF_8f3a9c'
metadata:
  id: ${REPO_OWNER}/${REPO_NAME}
  sourceRepo: github.com/${REPO_OWNER}/${REPO_NAME}
  contentVersion: abcd123 # Will be filled in during CI

title: Docker Developer Productivity — Inner Loop to AI
description: |
  A hands-on Labspace that takes you through the full inner-loop developer
  workflow with Docker — from running Postgres containers, through building,
  testing, and securing a real Product Catalog service, all the way to
  enhancing it with local AI using Docker Model Runner and the MCP Gateway.

author: Ajeet Singh Raina

sections:
  - title: Introduction
    contentPath: 00-introduction.md
  - title: "Lab 1 · Running Postgres Containers"
    contentPath: 01-postgres-containers.md
  - title: "Lab 2 · Product Catalog Overview"
    contentPath: 02-product-catalog-overview.md
  - title: "Lab 3 · Develop"
    contentPath: 03-develop.md
  - title: "Lab 4 · Test"
    contentPath: 04-test.md
  - title: "Lab 5 · Build"
    contentPath: 05-build.md
  - title: "Lab 6 · Secure"
    contentPath: 06-secure.md
  - title: "Lab 7 · Catalog + Docker Model Runner"
    contentPath: 07-model-runner.md
  - title: "Lab 8 · Catalog + MCP"
    contentPath: 08-mcp.md
  - title: Conclusion
    contentPath: 09-conclusion.md

# Services are used to add default tabs in the Labspace interface.
# The IDE is always present. Icons come from https://fonts.google.com/icons/
services:
  - id: app
    url: http://localhost:5173
    title: Web Client
    icon: storefront
  - id: pgadmin
    url: http://localhost:5050
    title: pgAdmin
    icon: database
  - id: kafka
    url: http://localhost:8080
    title: Kafka UI
    icon: forum
LABSPACE_EOF_8f3a9c

echo "    - labspace/00-introduction.md"
cat > 'labspace/00-introduction.md' <<'LABSPACE_EOF_8f3a9c'
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
LABSPACE_EOF_8f3a9c

echo "    - labspace/01-postgres-containers.md"
cat > 'labspace/01-postgres-containers.md' <<'LABSPACE_EOF_8f3a9c'
# Lab 1 · Running Postgres Containers

In this first lab you'll get comfortable with the inner-loop basics: starting containers, inspecting what's inside them, and tearing them down. We'll use **Postgres** because it's a real service you'll use throughout the rest of this Labspace.

## 🎓 Quick refresher: what is a container?

Think of containers like smartphone apps. When you install an app, you don't think about its dependencies, configuration, or setup — you just tap **Install** and it works. And the red app you just installed runs in its own isolated, sandboxed environment, so it can't interfere with the green app next to it.

Containers bring that same idea to backend applications and services. Each one ships with everything it needs and runs isolated from the others.

## Running multiple Postgres containers

Let's prove that isolation by running **three different Postgres versions side by side**, each on its own host port. Run each command below:

```bash
docker run -d --name postgres1 -e POSTGRES_PASSWORD=dev -p 5432:5432 postgres:latest
```

```bash
docker run -d --name postgres2 -e POSTGRES_PASSWORD=dev -p 5433:5432 postgres:13
```

```bash
docker run -d --name postgres3 -e POSTGRES_PASSWORD=dev -p 5434:5432 postgres:12
```

Three independent database engines — `latest`, `13`, and `12` — all running at once without conflict. Confirm they're up:

```bash
docker ps
```

## Connecting with psql

Exec into the first container and open a `psql` session:

```bash
docker exec -it postgres1 psql -d postgres -U postgres -W
```

When prompted, enter the password `dev`. You'll land in the interactive prompt:

```text no-run-button
psql (17.2 (Debian 17.2-1.pgdg120+1))
Type "help" for help.

postgres=#
```

The connection flags mean:

- `-d` — the name of the database to connect to
- `-U` — the user to connect as
- `-W` — force `psql` to prompt for the password before connecting

## Listing all the databases — `\l`

At the `postgres=#` prompt, list every database:

```text no-run-button
postgres=# \l
```

You'll see the three default databases that ship with a fresh Postgres install:

```text no-run-button no-copy-button
                                 List of databases
   Name    |  Owner   | Encoding | Locale Provider |  Collate   |   Ctype
-----------+----------+----------+-----------------+------------+------------
 postgres  | postgres | UTF8     | libc            | en_US.utf8 | en_US.utf8
 template0 | postgres | UTF8     | libc            | en_US.utf8 | en_US.utf8
 template1 | postgres | UTF8     | libc            | en_US.utf8 | en_US.utf8
(3 rows)
```

## Listing all schemas — `\dn`

The `\dn` command lists the database schemas:

```text no-run-button
postgres=# \dn
```

```text no-run-button no-copy-button
      List of schemas
  Name  |       Owner
--------+-------------------
 public | pg_database_owner
(1 row)
```

## Inspecting database activity

Postgres exposes a live view of what every connection is doing through the `pg_stat_activity` system view. Run the query (**don't forget the trailing `;`**):

```text no-run-button
postgres=# SELECT * FROM pg_stat_activity;
```

The result shows one row per backend process — the PID, the user, the client, the current `state` (`idle` / `active`), the wait event, and the actual `query` text. This is your first line of insight when a database "feels slow": you can see exactly which queries are running and which are blocked.

```text no-run-button no-copy-button
 datid | datname  | pid | usename  | application_name | state  |              query
-------+----------+-----+----------+------------------+--------+---------------------------------
     5 | postgres |  85 | postgres | psql             | idle   | SELECT pg_sleep(30);
     5 | postgres |  92 | postgres | psql             | active | SELECT * FROM pg_stat_activity;
       |          |  64 |          |                  |        |  (autovacuum launcher)
```

Exit the `psql` session when you're done:

```text no-run-button
postgres=# \q
```

## Cleaning up

When you remove containers, only the container layer is discarded — your host stays clean, with no leftover Postgres install, config files, or stray processes. That clean teardown is one of the core inner-loop benefits of containers.

Stop and remove all three Postgres containers in one step:

```bash
docker rm -f postgres1 postgres2 postgres3
```

> 💡 In Docker Desktop you can do the same visually: open the **Containers** view, select all the running Postgres containers, and delete them together.

## ✅ Recap

You ran three isolated Postgres versions simultaneously, connected with `psql`, explored databases, schemas, and live activity, and tore everything down cleanly. Next, we'll meet the application you'll spend the rest of this Labspace building and improving.
LABSPACE_EOF_8f3a9c

echo "    - labspace/02-product-catalog-overview.md"
cat > 'labspace/02-product-catalog-overview.md' <<'LABSPACE_EOF_8f3a9c'
# Lab 2 · Product Catalog Overview

Now that you're comfortable running containers, let's meet the application at the heart of this Labspace: the **Catalog Service**.

This is a demo project that exercises Docker's full set of capabilities in a single, realistic codebase. It includes:

- A containerized development environment (in a few setup varieties)
- Integration testing with Testcontainers
- Building in GitHub Actions

It's deliberately built to feel like a real production service rather than a toy example — so the workflow you learn here transfers directly to your own projects.

## 🏗️ Application architecture

The service exposes an API backed by four moving parts:

- **Data** is stored in a **PostgreSQL** database
- **Product images** are stored in an **AWS S3** bucket
- **Inventory data** comes from an external **inventory service**
- **Product updates** are published to a **Kafka** cluster

![Application architecture](https://github.com/user-attachments/assets/09509d15-4095-44f3-a478-189c733b9e20)

## 🧪 The development environment

Standing up four external dependencies on your laptop would normally be painful. With Docker, the dev environment provides all of them as containers:

- **PostgreSQL** and **Kafka** run directly in containers
- **LocalStack** runs S3 locally, so you never touch real AWS
- **WireMock** mocks the external inventory service
- **pgAdmin** and **kafbat (Kafka UI)** are added to visualize the database and the Kafka cluster

![Dev environment architecture](https://github.com/user-attachments/assets/e8e5790a-8e21-4331-9566-4db4861d7a65)

This is the inner loop in action: a single `docker compose up` gives every developer an identical, production-shaped environment in seconds — no "works on my machine," no manual setup.

## 📚 The tech stack at a glance

| Concern | Local (this Labspace) | Production equivalent |
|---|---|---|
| Database | PostgreSQL container | Managed PostgreSQL |
| Object storage | LocalStack (S3) | AWS S3 |
| Inventory | WireMock mock | Real inventory microservice |
| Event streaming | Kafka container | Managed Kafka |
| DB visualization | pgAdmin | — |
| Kafka visualization | Kafka UI | — |

## ✅ Prerequisites

Everything below is **already provided** inside this Labspace — this list is here so you know what a real local setup would require:

1. **Docker Desktop** — v4.27.2 or above
2. **Node.js** — version 22+ (needed for `npm install` to work cleanly)
3. **Access to the repository** — [`dockersamples/catalog-service-node`](https://github.com/dockersamples/catalog-service-node)
4. **Testcontainers Desktop** *(optional)* — a visual companion for the testing lab, from [testcontainers.com/desktop](https://testcontainers.com/desktop/)

> 💡 On Windows 11, a real setup also needs the WSL 2 engine enabled in **Docker Desktop → Settings → Resources → WSL Integration**.

## ✅ Recap

You now understand what the Catalog Service is, the four backing services it depends on, and how Docker provides every one of them locally. In the next lab, you'll bring this environment up and start developing against it.
LABSPACE_EOF_8f3a9c

echo "    - labspace/03-develop.md"
cat > 'labspace/03-develop.md' <<'LABSPACE_EOF_8f3a9c'
# Lab 3 · Develop

This is where the inner loop really comes alive. You'll bring up the full environment, create products through the web UI, watch them flow into Postgres and Kafka, **discover a bug**, and **fix it live** — all without leaving your containerized environment.

## Bring up the environment

The project is already cloned into this Labspace. Start all the backing services (Postgres, Kafka, LocalStack, WireMock, pgAdmin, Kafka UI):

```bash
docker compose up -d
```

Confirm everything is healthy:

```bash
docker compose ps
```

> 📝 In a real local setup you'd first clone the repo and run a prep script:
>
> ```bash no-run-button
> git clone https://github.com/dockersamples/catalog-service-node
> cd demo/sdlc-e2e
> ./setup.sh
> ```
>
> The `setup.sh` script creates a per-participant demo branch, cleans the working tree, pulls the latest code, applies a demo patch, runs `npm install`, and pre-pulls all the container images so the workshop starts instantly. Importantly, the patch **deliberately removes** the `upc: product.upc,` line from `src/services/ProductService.js` — that's the bug you'll fix below.

## Start the API service

With the dependencies running, start the application itself in dev mode (live reload is enabled):

```bash
npm install
```

```bash
npm run dev
```

Once it's up, open the **Web Client** tab (or :tabLink[open it here]{href="http://localhost:5173" title="Web Client"}) at [http://localhost:5173](http://localhost:5173) and **create a few products**.

## Verify the data landed in Postgres

Open the **pgAdmin** tab at [http://localhost:5050](http://localhost:5050) and confirm the products exist. Use the password `postgres` to log in.

You can also check directly from the database container:

```bash
docker compose exec postgres psql -U postgres -c "\c catalog" -c "SELECT * FROM products;"
```

```text no-run-button no-copy-button
catalog=# SELECT * FROM products;
  1 | New Product | 100000000001 | 100.00 | f
  2 | New Product | 100000000002 | 100.00 | f
  3 | New Product | 100000000003 | 100.00 | f
```

✅ Good — the UPCs are persisted in the database.

## 🐞 Find the bug: inspect the Kafka messages

Every time a product is created, the service is supposed to publish an event to Kafka with the full product details. Open the **Kafka UI** tab at [http://localhost:8080](http://localhost:8080) and look at the messages published to the `products` topic.

![Kafka messages missing the UPC](https://github.com/user-attachments/assets/a3e3ff3d-f08c-4168-bfb2-e59800be4d58)

Look closely... **the messages don't include the UPC!** Downstream consumers that rely on those events would be missing a critical field. This is exactly the kind of subtle integration bug the inner loop is designed to catch fast.

## 🔧 Fix it

In the editor, open `src/services/ProductService.js` and find the `publishEvent` call (around line 52). Add the missing field:

```javascript no-run-button
upc: product.upc,
```

So the published payload includes the UPC alongside the other product fields.

Because the app runs in dev mode with live reload, **just save the file** — no restart needed. Now create a new product from the web UI again.

## ✅ Verify the fix

Head back to the **Kafka UI** and inspect the newest message on the `products` topic.

![Kafka message now includes the UPC](https://github.com/user-attachments/assets/32c5ba6c-60c1-403b-9962-50c501a5e996)

The UPC is now present in the event payload. 🎉

## ✅ Recap

You ran the full environment with one command, created data, traced it through Postgres and Kafka, found a real integration bug, and fixed it with a live edit — the complete inner loop in a single sitting. Next, you'll lock this behavior in with automated tests so the bug can never silently return.
LABSPACE_EOF_8f3a9c

echo "    - labspace/04-test.md"
cat > 'labspace/04-test.md' <<'LABSPACE_EOF_8f3a9c'
# Lab 4 · Test

In this lab you'll add automated tests for the containerized application using **Testcontainers**. The big idea: run your tests against *real* services in throwaway containers, so your tests match production far more closely than mocks ever could.

## 🧪 Understanding Testcontainers

[Testcontainers](https://testcontainers.com/) is a library that gives you lightweight, throwaway instances of databases, message brokers, or anything else that runs in a container. It's ideal for integration testing because:

- It creates **isolated** environments for each test run
- It spins up **actual services** rather than mocks (when you need realism)
- It **cleans up automatically** after tests finish
- It's **language-agnostic** (we'll use the JavaScript implementation)

## Prerequisites

Before running the tests, make sure you have:

- Docker running (it is, in this Labspace)
- *(Optional)* [Testcontainers Desktop](https://testcontainers.com/desktop/) for a visual view of test containers
- Completed **Lab 3 · Develop**

## 🗂️ How the tests are structured

The application uses two kinds of tests:

1. **Unit tests** — exercise individual functions with no external dependencies
2. **Integration tests** — exercise complete features against real dependencies (via Testcontainers)

Key integration test files:

- `containerSupport.js` — manages the container lifecycle for tests
- `kafkaSupport.js` — Kafka testing utilities
- `productCreation.integration.test.js` — tests product creation end to end

## Running the unit tests

Unit tests verify individual functions in isolation — fast feedback, no containers:

```bash
npm run unit-test
```

## Running the integration tests

```bash
npm run integration-test
```

When these run, Testcontainers will:

1. Spin up the required containers (PostgreSQL, Kafka, LocalStack)
2. Run the tests against those real containers
3. Tear the containers down when the run completes

You can watch the containers appear and disappear in Docker Desktop or Testcontainers Desktop:

![Testcontainers in action](https://github.com/user-attachments/assets/9277a932-2227-4cf2-97ab-758e1dd3ea38)

## 🔍 Inside the integration test

### Container setup

The support file starts each dependency in its own container and wires the connection details into environment variables:

```javascript no-run-button
// From containerSupport.js
async function setup() {
  // Start PostgreSQL container
  postgres = await new GenericContainer("postgres:15")
    .withExposedPorts(5432)
    .withEnvironment({ POSTGRES_PASSWORD: "postgres" })
    .start();

  // Start Kafka container
  kafka = await new GenericContainer("confluentinc/cp-kafka:7.4.0")
    .withExposedPorts(9092)
    .withEnvironment({
      KAFKA_ADVERTISED_LISTENERS: "PLAINTEXT://localhost:9092",
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
    })
    .start();

  // Start LocalStack (for S3)
  localstack = await new GenericContainer("localstack/localstack:2.2")
    .withExposedPorts(4566)
    .start();

  // Configure environment variables for tests
  process.env.DATABASE_URL = `postgres://postgres:postgres@localhost:${postgres.getMappedPort(5432)}/postgres`;
  process.env.KAFKA_BROKER = `localhost:${kafka.getMappedPort(9092)}`;
  process.env.S3_ENDPOINT = `http://localhost:${localstack.getMappedPort(4566)}`;
}
```

Each test run gets fresh, isolated containers for every service the app depends on.

### Test cases

```javascript no-run-button
// From productCreation.integration.test.js
describe("Product creation", () => {
  it("should publish and return a product when creating a product", async () => {
    const product = { name: "Test Product", upc: "123456789012", price: 9.99 };

    const createdProduct = await productService.createProduct(product);

    expect(createdProduct.id).toBeDefined();
    expect(createdProduct.name).toBe(product.name);
    expect(createdProduct.upc).toBe(product.upc);
    expect(createdProduct.price).toBe(product.price);

    const retrievedProduct = await productService.getProduct(createdProduct.id);
    expect(retrievedProduct).toEqual(createdProduct);
  });

  it("should publish a Kafka message when creating a product", async () => {
    const product = { name: "Kafka Test Product", upc: "123456789013", price: 19.99 };

    await productService.createProduct(product);

    const message = await kafkaConsumer.waitForMessage("products", 5000);
    expect(message).toBeDefined();
    expect(message.action).toBe("product_created");
    expect(message.name).toBe(product.name);
    expect(message.upc).toBe(product.upc);   // 👈 this assertion guards the bug you fixed in Lab 3
    expect(message.price).toBe(product.price);
  });
});
```

Notice the second test asserts that the Kafka message contains the `upc` — exactly the field you fixed in Lab 3. With this test in place, that bug can never silently come back.

These tests verify that products can be created and retrieved, Kafka messages publish correctly, file uploads work, and business rules (like preventing duplicate UPCs) are enforced.

## 💡 Why Testcontainers for integration testing

1. **Realistic** — tests run against actual services, not mocks
2. **Isolated** — each run gets fresh containers
3. **Portable** — identical behavior on any machine with Docker
4. **Parallelizable** — isolated containers allow parallel runs
5. **CI/CD-friendly** — works the same in your pipeline as on your laptop

## 🧰 Common container-based testing patterns

- **Database testing** — a containerized DB with a known schema and seed data
- **Message-queue testing** — verify publishing and consuming with a real broker
- **API testing** — hit API endpoints against containerized dependencies
- **End-to-end testing** — containerize every service to test full workflows

## 🛠️ Troubleshooting

- **Port conflicts** — make sure nothing else is using the same ports
- **Docker connection** — verify Docker is running and reachable
- **Resource limits** — give Docker enough CPU and memory
- **Network issues** — ensure containers can talk to each other

## ✅ Recap

You ran unit and integration tests, saw Testcontainers spin real dependencies up and tear them down automatically, and locked in the Lab 3 fix with a regression test. Next, you'll build the application into an image.
LABSPACE_EOF_8f3a9c

echo "    - labspace/05-build.md"
cat > 'labspace/05-build.md' <<'LABSPACE_EOF_8f3a9c'
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
LABSPACE_EOF_8f3a9c

echo "    - labspace/06-secure.md"
cat > 'labspace/06-secure.md' <<'LABSPACE_EOF_8f3a9c'
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
LABSPACE_EOF_8f3a9c

echo "    - labspace/07-model-runner.md"
cat > 'labspace/07-model-runner.md' <<'LABSPACE_EOF_8f3a9c'
# Lab 7 · Catalog + Docker Model Runner

Time to make the catalog *smart*. In this lab you'll run a version of the service enhanced with a **conversational AI chatbot** powered by **Docker Model Runner** — a local LLM running entirely on your machine, no external API keys, no data leaving your environment.

> Repo for this lab: [`ajeetraina/catalog-service-node-chatbot`](https://github.com/ajeetraina/catalog-service-node-chatbot)

## 🤖 What is Docker Model Runner?

Docker Model Runner lets you pull and run open large language models the same way you run containers — with a familiar `docker model` command. The model serves an OpenAI-compatible endpoint locally, so your application code talks to it just like it would talk to a hosted API, but everything stays on your machine.

## 🏗️ What you'll be running

This enhanced system layers AI services on top of the catalog you already know:

```text no-run-button no-copy-button
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   Frontend      │  │  Agent Portal   │  │  Chatbot UI     │
│   Port: 5173    │  │   Port: 3001    │  │   Port: 5174    │
└─────────────────┘  └─────────────────┘  └─────────────────┘
        │                     │                     │
        └──────────┬──────────┴─────────┬───────────┘
                   │                     │
        ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
        │   Backend API   │  │ Agent Service   │  │  Chatbot API    │
        │   Port: 3000    │  │  Port: 7777     │  │  Port: 8082     │
        └─────────────────┘  └─────────────────┘  └─────────────────┘
                   │                     │                     │
                   └──────────┬──────────┴─────────┬───────────┘
                              │                     │
                    ┌─────────────────┐  ┌─────────────────┐
                    │  MCP Gateway    │  │  Model Runner   │
                    │  Port: 8811     │  │  (Local AI)     │
                    └─────────────────┘  └─────────────────┘
```

## Prerequisites

- Docker Desktop with **Model Runner enabled**
- At least **8 GB RAM** (4 GB+ for the AI models)
- Docker Compose v2.0+

## Step 1 · Pull the AI model

Pull the Llama 3.2 model that the chatbot and agents will use:

```bash
docker model pull ai/llama3.2:1B-Q8_0
```

You can list locally available models at any time:

```bash
docker model ls
```

## Step 2 · Start all services

Clone the enhanced repo and bring everything up:

```bash
git clone https://github.com/ajeetraina/catalog-service-node-chatbot.git
```

```bash
cd catalog-service-node-chatbot && docker compose up -d --build
```

## Step 3 · Access the applications

| Service | URL | Description |
|---|---|---|
| 🤖 **Chatbot Interface** | [http://localhost:5174](http://localhost:5174) | **Main chatbot for product queries** |
| 🏠 Main Frontend | [http://localhost:5173](http://localhost:5173) | Product catalog management |
| 🔧 Agent Portal | [http://localhost:3001](http://localhost:3001) | AI agent management interface |
| 📊 Kafka UI | [http://localhost:8080](http://localhost:8080) | Event streaming monitoring |
| 🗄️ pgAdmin | [http://localhost:5050](http://localhost:5050) | Database administration |

> 💡 Load sample data first: running `sh add-products.sh` seeds 50+ products so the chatbot has a rich catalog to answer questions about.

```bash
sh add-products.sh
```

## Step 4 · Chat with your catalog

Open the **Chatbot Interface** at [http://localhost:5174](http://localhost:5174) and try natural-language queries. For example:

```text no-run-button
Show me all electronics under $500
```

The chatbot understands the intent, searches the catalog, and replies conversationally:

```text no-run-button no-copy-button
I found 8 electronics products under $500:

📱 iPhone SE - $399.00
🎧 Sony WH-1000XM5 - $399.00
⌚ Apple Watch - $249.00
...
Would you like details about any specific product?
```

Try a few more — they all run through the **local** Llama model:

```text no-run-button
What's popular in home electronics?
```

```text no-run-button
Give me a summary of the catalog
```

## ⚙️ How Model Runner is wired in

The integration is declared in `compose.yaml` using the top-level `models` block, and each service references it through environment variables:

```yaml no-run-button
models:
  llama_model:
    model: ai/llama3.2:1B-Q8_0

chatbot-backend:
  models:
    llama_model:
      endpoint_var: MODEL_RUNNER_URL
      model_var: MODEL_RUNNER_MODEL
```

At runtime, Compose injects `MODEL_RUNNER_URL` and `MODEL_RUNNER_MODEL` into the service, and the app calls the local model through its OpenAI-compatible endpoint — no code changes needed to swap models.

## Choosing a model

Model Runner supports a range of sizes; pick based on your machine and the task:

| Model | Size | Performance | Use case |
|---|---|---|---|
| `ai/llama3.2:1B-Q4_0` | ~1 GB | Fast | Chatbot, basic agents |
| `ai/llama3.2:1B-Q8_0` | ~1.5 GB | Balanced | **Recommended** |
| `ai/llama3.2:3B-Q4_0` | ~2 GB | High quality | Complex agent tasks |

## ✅ Recap

You pulled a local LLM with Docker Model Runner, brought up an AI-enhanced catalog, seeded it with data, and chatted with your own catalog in natural language — all running locally. In the final lab, you'll see how the **MCP Gateway** lets AI agents reach beyond the catalog to external tools.
LABSPACE_EOF_8f3a9c

echo "    - labspace/08-mcp.md"
cat > 'labspace/08-mcp.md' <<'LABSPACE_EOF_8f3a9c'
# Lab 8 · Catalog + MCP

In this final lab you'll run the fully **AI-powered, multi-agent** version of the catalog. It uses the **Docker MCP Gateway** to orchestrate AI tools and a team of specialized agents to automatically evaluate product submissions — all backed by a local LLM via Docker Model Runner.

> Repo for this lab: [`ajeetraina/catalog-service-ai-enhanced`](https://github.com/ajeetraina/catalog-service-ai-enhanced)

## 🧩 What is the MCP Gateway?

The **Model Context Protocol (MCP)** is a standard way for AI models to call external tools — fetching web pages, querying databases, sending email, and more. The **Docker MCP Gateway** is the orchestration layer that exposes those tools to your agents securely over a single endpoint, so each agent can reach the data it needs without bespoke integration code.

## 🏗️ Architecture

A microservices system where AI agents evaluate products automatically:

- **Frontend (React)** — product submission interface
- **Backend API** — Node.js REST API
- **Agent Service** — the core AI evaluation engine
- **Agent Portal** — admin interface for managing agents
- **MCP Gateway** — tool orchestration layer
- **Docker Model Runner** — local LLM execution
- **Databases** — PostgreSQL (catalog) + MongoDB (agent history)
- **Kafka** — event streaming in KRaft mode

## 🤖 The four AI agents

| Agent | Role |
|---|---|
| **Vendor Intake Agent** | Evaluates product submissions with a 0–100 score |
| **Market Research Agent** | Performs automated competitor analysis |
| **Customer Match Agent** | Analyzes customer preferences |
| **Catalog Management Agent** | Updates and maintains the product catalog |

## Step 1 · Clone and configure

```bash
git clone https://github.com/ajeetraina/catalog-service-ai-enhanced.git
```

```bash
cd catalog-service-ai-enhanced && cp .env.example .env
```

> 📝 Edit `.env` to add any API keys the external MCP tools require. The local AI evaluation works without external keys.

## Step 2 · Start the services

```bash
docker compose up -d
```

## Step 3 · Access the applications

| Service | URL |
|---|---|
| Frontend | [http://localhost:5173](http://localhost:5173) |
| Agent Portal | [http://localhost:3001](http://localhost:3001) |
| API | [http://localhost:3000](http://localhost:3000) |
| pgAdmin | [http://localhost:5050](http://localhost:5050) |
| Kafka UI | [http://localhost:8080](http://localhost:8080) |

## 🧠 How the AI evaluation works

Each agent is configured with a role, a model, and (for the gatekeeper) a scoring threshold:

```javascript no-run-button
const agents = {
  vendorIntake: {
    name: 'Vendor Intake Agent',
    role: 'Evaluates vendor submissions using Docker Model Runner',
    threshold: 70,             // rejection threshold
    model: 'ai/llama3.2:latest'
  },
  marketResearch: { /* Competitor analysis */ },
  customerMatch:  { /* Customer preference matching */ },
  catalog:        { /* Catalog management */ }
}
```

When you submit a product, the flow is:

**Frontend → Backend → Agent Service (`/products/evaluate`)**

The Agent Service builds an evaluation prompt and sends it to the local model:

```text no-run-button
You are an expert product evaluator...

Product Details:
- Vendor: ${product.vendorName}
- Product Name: ${product.productName}
- Description: ${product.description}
- Price: $${product.price}
- Category: ${product.category}

Evaluation Criteria (100 points total):
- Product innovation and quality (25 points)
- Market demand and competitiveness (25 points)
- Description clarity and completeness (20 points)
- Price appropriateness (15 points)
- Vendor credibility (15 points)

Minimum passing score: 70/100
```

The call goes to Docker Model Runner locally at `http://model-runner.docker.internal/engines/v1/chat/completions` using the Llama 3.2 model, with a 60-second timeout.

The agent returns a structured decision:

```json no-run-button
{
  "score": 87,
  "decision": "APPROVED",
  "reasoning": "Detailed AI analysis...",
  "category_match": "Electronics - Perfect match",
  "market_potential": "High"
}
```

## Step 4 · Submit a product

Open the **Frontend** at [http://localhost:5173](http://localhost:5173) and submit a product for evaluation:

```text no-run-button
Vendor: NVIDIA
Product: Jetson Nano Super
Description: Jetson Nano is a tiny computer for AI applications.
Price: 249.0
Category: Electronics
```

## Step 5 · Watch the agents work

Follow the agent service logs to watch the evaluation happen in real time:

```bash
docker compose logs -f agent-service
```

```text no-run-button no-copy-button
📝 New product evaluation request: {
  "vendorName": "NVIDIA",
  "productName": "Jetson Nano Super",
  "price": "249",
  "category": "Electronics"
}
🤖 Calling Docker Model Runner...
🔗 API URL: http://model-runner.docker.internal/engines/v1/chat/completions
🧠 Model: ai/llama3.2:latest
✅ Docker Model Runner response received
🎯 AI Evaluation Result:
   Score: 87/100
   Decision: APPROVED
   Processing Time: 6169ms
```

Because 87 is above the 70 threshold, the product is **approved**. 🎉

## 🔄 Where the data goes

- **Evaluation results** → MongoDB (`agent_history`)
- **Approved products** → PostgreSQL (`catalog_db`)
- **Event stream** → Kafka (`product-evaluations` topic)
- **Admin monitoring** → Agent Portal UI

Open the **Agent Portal** at [http://localhost:3001](http://localhost:3001) to see the evaluation history, and check **Kafka UI** at [http://localhost:8080](http://localhost:8080) to watch the evaluation events flow through the `product-evaluations` topic.

## ✅ Recap

You ran a complete multi-agent AI system that evaluates product submissions automatically — combining the MCP Gateway for tool orchestration, Docker Model Runner for local inference, and the event-driven architecture (Postgres, MongoDB, Kafka) you've been building on since Lab 2. This is "Agents as the new microservices" in practice: modular, composable, isolated AI services, each doing one job well.
LABSPACE_EOF_8f3a9c

echo "    - labspace/09-conclusion.md"
cat > 'labspace/09-conclusion.md' <<'LABSPACE_EOF_8f3a9c'
# Conclusion

🎉 You've completed the **Docker Developer Productivity** Labspace!

You started with the fundamentals of running containers and ended up running a multi-agent AI system — all within the same tight, containerized inner loop.

## ✅ What you accomplished

- **Lab 1** — Ran multiple isolated Postgres containers, explored them with `psql`, and tore them down cleanly
- **Lab 2** — Mapped the Product Catalog architecture and its containerized dev environment
- **Lab 3** — Developed against the full stack, found a Kafka/UPC bug, and fixed it live
- **Lab 4** — Wrote and ran integration tests with Testcontainers, locking in your fix
- **Lab 5** — Built the application image locally and learned how caching and Buildx speed things up
- **Lab 6** — Scanned for vulnerabilities with Docker Scout and remediated them
- **Lab 7** — Added a conversational chatbot powered by a local LLM via Docker Model Runner
- **Lab 8** — Ran a multi-agent evaluation system orchestrated through the Docker MCP Gateway

## 🔁 The bigger picture

Every lab reinforced the same idea: Docker collapses the distance between your laptop and production. The **inner loop** — develop, test, build, secure — stays fast and local, while the artifacts and workflows you produce carry cleanly into the **outer loop** of CI/CD and release. And as you saw in the final labs, that same model extends naturally to AI: agents and models are just more containers, composed and isolated like any other service.

## 🚀 Next steps

- Wire the build and tests into a **GitHub Actions** pipeline to automate your outer loop
- Try a **proactive** security posture with **Docker Hardened Images (DHI)** as your base
- Swap in different models with **Docker Model Runner** and compare quality vs. speed
- Add your own **MCP tools** to give the agents new capabilities
- Explore **Docker Sandboxes** for running AI coding agents safely in microVM isolation

Thanks for building along! 🐳
LABSPACE_EOF_8f3a9c

echo "    - compose.override.yaml"
cat > 'compose.override.yaml' <<'LABSPACE_EOF_8f3a9c'
services:
  configurator:
    environment:
      PROJECT_CLONE_URL: https://github.com/${REPO_OWNER}/${REPO_NAME}

  workspace:
    # Publish the ports used across the labs so the service tabs and
    # in-Labspace links resolve correctly.
    ports: !override
      - "5173:5173" # Catalog web client / frontend
      - "5174:5174" # Chatbot UI (Lab 7)
      - "3000:3000" # Backend API
      - "3001:3001" # Agent Portal (Labs 7 & 8)
      - "5050:5050" # pgAdmin
      - "8080:8080" # Kafka UI
      - "5432:5432" # PostgreSQL
      - "9092:9092" # Kafka broker
      - "4566:4566" # LocalStack (S3)
      - "8090:8090" # WireMock (mock inventory)
      - "7777:7777" # Agent Service (Labs 7 & 8)
      - "8082:8082" # Chatbot API (Lab 7)
      - "8811:8811" # MCP Gateway (Labs 7 & 8)

# Add other models or services your Labspace may need
LABSPACE_EOF_8f3a9c

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo "==> Labspace content installed successfully."
echo ""
echo "    Sections written : 10 (intro + 8 labs + conclusion)"
echo "    compose.override : updated (ports for all labs)"
if [ -d "$BACKUP_DIR" ]; then
  echo "    Backup of originals: ./$BACKUP_DIR/"
fi
echo ""
echo "Next steps:"
echo "  # Mac/Linux"
echo "  CONTENT_PATH=\$PWD docker compose up --watch"
echo ""
echo "  # Windows PowerShell"
echo "  \$Env:CONTENT_PATH = (Get-Location).Path; docker compose up --watch"
echo ""
echo "Then open the Labspace in your browser. Edits to labspace/*.md reload live."
