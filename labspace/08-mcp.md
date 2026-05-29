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

## Step 0 · Start with a clean slate

Other labs leave containers running on the same ports this stack needs — especially **port 5432** (PostgreSQL) and the AI-related stacks from Lab 7. Clear them in one pass:

```bash
docker rm -f $(docker ps -aq --filter "name=postgres" --filter "name=catalog-service-node" --filter "name=catalog-service-node-chatbot") 2>/dev/null; \
docker rm -f postgres1 postgres2 postgres3 2>/dev/null; \
echo "Cleaned up."
```

> 💡 The rule of thumb for this workshop: only one application stack runs at a time. Each lab's app reuses the same ports, so clear the previous one before starting the next.
>
> Port 3000 is a special case — inside a Labspace, the workspace itself holds it permanently, and `docker rm` can't free it. That's exactly why Step 2 below remaps the backend off port 3000.

## Step 1 · Clone and configure

Clone into `~/project` — the Labspace only allows bind-mounts from paths under that directory, so cloning anywhere else (like `~/`) will cause Docker to refuse WireMock's mapping mount later with *"Mounting … is not allowed"*:

```bash
cd ~/project && git clone https://github.com/ajeetraina/catalog-service-ai-enhanced.git
```

```bash
cd catalog-service-ai-enhanced && cp .env.example .env
```

```bash
mkdir -p wiremock/__files
```

> 📝 Edit `.env` to add any API keys the external MCP tools require. The local AI evaluation works without external keys.
>
> The `mkdir` step matters because the repo ships `wiremock/mappings/` but not `wiremock/__files/` — Docker can't bind-mount a path that doesn't exist, so creating the empty directory now saves a failed `up` later.

## Step 2 · Map the backend off port 3000

The backend listens on port 3000, but in a Labspace that port is already taken by the workspace itself (which `docker rm` can't remove — it's the Labspace you're working in). Add a small override that maps the backend to host port **3002**, keeping its internal port unchanged:

```bash
cat > compose.override.yaml <<'OVERRIDE'
services:
  backend:
    ports: !override
      - "3002:3000"
OVERRIDE
```

> 💡 Harmless outside a Labspace too — the API just lives at `localhost:3002`. Services still reach each other internally on `backend:3000`, so the app works the same.

## Step 3 · Start the services

```bash
docker compose up -d
```

Verify every container is `Up` — not just `Created`:

```bash
docker compose ps -a
```

> 💡 If a container is left in **`Created`** state (an earlier start didn't finish), just run `docker compose up -d` again — it starts the stragglers without disturbing the running ones.

## Step 4 · Access the applications

> 🌐 **Open these in your own browser**, not the Labspace service tabs at the top. Those tabs serve the catalog stack from Labs 3–6; this AI stack runs separately on its own ports, so reach it directly at the URLs below.

| Service | URL |
|---|---|
| Frontend | [http://localhost:5173](http://localhost:5173) |
| Agent Portal | [http://localhost:3001](http://localhost:3001) |
| API | [http://localhost:3002](http://localhost:3002) |
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

## Step 5 · Submit a product

Open the **Frontend** at [http://localhost:5173](http://localhost:5173) and submit a product for evaluation:

```text no-run-button
Vendor: NVIDIA
Product: Jetson Nano Super
Description: Jetson Nano is a tiny computer for AI applications.
Price: 249.0
Category: Electronics
```

## Step 6 · Watch the agents work

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
