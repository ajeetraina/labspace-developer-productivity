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

## Step 2 · Clone the enhanced repo

Clone the chatbot-enhanced catalog repo. Run this from `~/project` so it sits **alongside** `catalog-service-node`, not nested inside it:

```bash
cd ~/project && git clone https://github.com/ajeetraina/catalog-service-node-chatbot.git
```

Move into the project — every command below runs from here:

```bash
cd catalog-service-node-chatbot
```

> 📂 If you're running the catalog labs (3–6) in the same session, **stop that stack first** — both stacks publish ports like 5432, 5173, 8080 and 9092, so they can't run at the same time. From the catalog folder: `docker compose down`.

## Step 3 · Create the WireMock files directory

The repo's `compose.yaml` mounts `./wiremock/__files`, but that directory isn't included in the repo — only `wiremock/mappings/` is. Docker can't bind-mount a path that doesn't exist, so **WireMock will fail to start** unless you create it first:

```bash
mkdir -p wiremock/__files
```

> 💡 An empty `__files` directory is fine — WireMock only uses it for file-based response bodies, and this repo's stubs are all inline JSON. This step just satisfies the bind mount.

## Step 4 · Start all services

Build and bring up the full stack:

```bash
docker compose up -d --build
```

> ⚠️ **Port 3000 already in use?** If `up` fails with *"Bind for 0.0.0.0:3000 failed: port is already allocated,"* something else on your host is using port 3000 — most commonly the **Labspace workspace itself** (it publishes 3000). The backend listens on 3000 *inside* its container; just map it to a free host port instead. Create a `compose.override.yaml` **in this directory**:
>
> ```bash no-run-button
> cat > compose.override.yaml <<'OVERRIDE'
> services:
>   backend:
>     ports: !override
>       - "3002:3000"
> OVERRIDE
> ```
>
> Then re-run `docker compose up -d`. The backend is now reachable on host port `3002` (services still reach each other internally on `backend:3000`, so the app is unaffected).

After `up`, **verify every container is actually running** — not just `Created`:

```bash
docker compose ps -a
```

> 💡 If an earlier `up` failed partway (e.g. on the port conflict above), some containers — often the `frontend`, `chatbot-frontend`, and `chatbot-backend` — can be left in **`Created`** state and never started. The UIs won't load until they're `Up`. Just run `docker compose up -d` again; it starts the stranded containers without disturbing the running ones.

## Step 5 · Access the application

This lab is about the **Chatbot** powered by Docker Model Runner — that's the one UI you need:

| Service | URL | Description |
|---|---|---|
| 🤖 **Chatbot** | [http://localhost:5174](http://localhost:5174) | **The Product Catalog Assistant — this is the lab** |

> 💬 In the Labspace, open the **Chatbot** tab at the top of the interface. It points at port 5174 — the purple "Product Catalog Assistant" chat UI. **Don't** use the *Web Client* tab (port 5173) for this lab; that's a generic catalog frontend, not the chatbot, and it can show a different app if another stack is running.

<details>
<summary>Optional — other UIs in this stack</summary>

The stack also runs supporting services you can peek at, but they aren't needed to complete the lab: Agent Portal ([3001](http://localhost:3001)), Kafka UI ([8080](http://localhost:8080)), and pgAdmin ([5050](http://localhost:5050)). Note these ports overlap with the Labs 3–6 catalog stack, so they only resolve correctly when this is the only stack running.

</details>

## Step 6 · Seed the catalog with sample data

⚠️ **Do this before chatting.** The catalog starts **empty** — if you ask the chatbot "show me electronics" with no products loaded, it has nothing to answer with. Seed 50+ sample products first:

```bash
sh add-products.sh
```

Confirm the products landed:

```bash
docker compose exec postgres psql -U postgres -d catalog -c "SELECT count(*) FROM products;"
```

You should see a non-zero count. Now the chatbot has a real catalog to draw on.

## Step 7 · Chat with your catalog

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
