# Running catalog-service-node on Docker Offload

## Prerequisites

- Docker CLI with the `offload` plugin
- An active Docker account
- Network access from your machine

Verify Offload is available:

```bash
docker offload version
```

## Step 1 — Clone the repo

```bash
cd ~/project
```

```bash
git clone https://github.com/dockersamples/catalog-service-node
```

```bash
cd catalog-service-node
```

## Step 2 — Start Offload

```bash
docker offload start
```

Authenticate when prompted. Confirm the context switched:

```bash
docker context show
```

You should see an offload context (e.g. `offload-cloud`).

## Step 3 — Update the Vite config

```bash
cat > dev/webapp/vite.config.js <<'EOF'
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    host: "0.0.0.0",
    proxy: {
      "/api": {
        target: process.env.VITE_BACKEND_URL || "http://host.docker.internal:3000",
        changeOrigin: true,
      },
    },
  },
});
EOF
```

## Step 4 — Create the compose override

```bash
cat > compose.override.yaml <<'EOF'
services:
  backend:
    build:
      context: .
      target: final
    ports:
      - "3005:3000"
    environment:
      NODE_ENV: development
      PGHOST: postgres
      PGPORT: 5432
      PGUSER: postgres
      PGPASSWORD: postgres
      PGDATABASE: catalog
      KAFKA_BOOTSTRAP_SERVERS: kafka:9093
      AWS_ENDPOINT_URL: http://aws:4566
      AWS_ACCESS_KEY_ID: test
      AWS_SECRET_ACCESS_KEY: test
      AWS_REGION: us-east-1
      INVENTORY_SERVICE_BASE_URL: http://mock-inventory:8080
    depends_on:
      - postgres
      - kafka
      - aws
      - mock-inventory

  demo-client:
    environment:
      VITE_BACKEND_URL: http://backend:3000
EOF
```

## Step 5 — Blank out the .env file

```bash
[ -f .env ] && cp .env .env.localdev
```

```bash
cat > .env <<'EOF'
# Values overridden by compose.override.yaml when running on Offload.
EOF
```

## Step 6 — Build and start the stack

```bash
docker compose down --remove-orphans
```

```bash
docker compose up -d --build
```

Wait about a minute for everything to start.

## Step 7 — Verify

```bash
docker compose ps
```

All 8 services should show `Up`: backend, demo-client, postgres, pgadmin, kafka, kafka-ui, mock-inventory, aws.

```bash
docker compose exec demo-client getent hosts backend
```

You should see an IP for `backend`.

```bash
docker compose exec backend node -e "fetch('http://localhost:3000/api/products').then(r=>r.text()).then(console.log)"
```

Output: `[]`

## Step 8 — Open the app

Open `http://localhost:5173` in your browser. Click **Create product** to add an entry.

Verify it persisted:

```bash
docker compose exec postgres psql -U postgres -d catalog -c "SELECT id, name, upc FROM products;"
```

## Step 9 — Apply backend code changes

```bash
docker compose up -d --build backend
```

## Step 10 — Teardown

```bash
docker compose down --remove-orphans
```

```bash
docker offload stop
```

```bash
docker context show
```

Should return to `default`.

## Restore local-dev

```bash
[ -f .env.localdev ] && mv .env.localdev .env
```

```bash
rm compose.override.yaml
```
