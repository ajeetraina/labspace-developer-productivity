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
