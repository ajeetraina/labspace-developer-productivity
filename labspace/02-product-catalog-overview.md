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
