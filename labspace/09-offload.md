# Docker Offload Reference — catalog-service-node

> Status: working but with caveats. Captures everything we learned debugging the
> stack on Offload. Read the *Known walls* section first — it'll save you hours.

---

## What this enables

The full `catalog-service-node` stack (postgres, kafka, mock-inventory,
localstack, kafka-ui, pgadmin, demo-client frontend, **plus a containerised
backend**) running entirely on Docker Offload's remote engine. Your Mac browser
reaches the frontend at `localhost:5173` via the Offload tunnel. No native
`npm run dev` required — everything's in the cloud.

---

## Known walls — read this first

The upstream `catalog-service-node` repo was designed around local-dev Docker
conventions. Each of these had to be worked around to run on Offload:

1. **`./dev/*` bind mounts.** Offload's remote engine has no access to your
   Labspace/Mac filesystem. The original `compose.yaml` bind-mounts `./dev/db`,
   `./dev/webapp`, and `./dev/inventory-mocks`. On Offload these resolve to
   nothing on the remote host and the affected containers fail to start.

2. **`docker compose watch` is unreliable on Offload.** Watch uses internal
   mount-like primitives that Offload's policy sometimes rejects with
   `Mounting <hash> is not allowed`. We dropped watch entirely.

3. **The repo expects you to run `npm run dev` natively.** There's no `backend`
   service in `compose.yaml`. The frontend's Vite config proxies `/api/*` to
   `host.docker.internal:3000` — which on Offload resolves to the **cloud VM's
   localhost**, not your Mac. The fix is to add a containerised `backend`
   service.

4. **The backend reads `PGHOST` (no underscore), not `PG_HOST`.** Postgres
   conventions. The repo's `.env` file ships with `PGHOST=localhost` which
   takes precedence over our compose env unless we override the env var with
   the exact same name *or* blank out the `.env` file.

5. **The Dockerfile's `dev` stage doesn't COPY source into the image.** It
   expects bind-mounted source at runtime. On Offload that doesn't work; we
   have to use the `final` stage which DOES include `COPY ./src ./src`. The
   tradeoff: no hot reload. Code changes require `docker compose up -d --build
   backend` (10-15s).

6. **`external: true` networks block silently breaks fresh `up`.** If you
   declare the network as external in the override, then `docker compose down`
   destroys it, the next `up` can't reattach, and Compose **silently skips
   creating affected services** instead of erroring. Don't declare networks
   as external in the override.

7. **`node:lts-slim` ships without `curl` or `wget`.** Test connectivity
   between containers with `node -e "fetch(...)..."` instead.

---

## Required files

### File 1: `dev/webapp/vite.config.js`

Replace the existing config — makes the proxy target configurable via env var,
while preserving original local-dev behaviour:

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

### File 2: `compose.override.yaml`

Adds a containerised backend, wires the frontend to it, uses the env var
names the code actually reads. No `external: true` networks declaration.

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

### File 3: `.env` — blank it out

The repo's `.env` has `PGHOST=localhost` which can leak into the container and
override our compose env. Save the original and replace with a stub:

```bash
[ -f .env ] && cp .env .env.localdev
cat > .env <<'EOF'
# Values overridden by compose.override.yaml when running on Offload.
# Original local-dev values preserved in .env.localdev
EOF
```

---

## Procedure

### Phase 1 — Start Offload

```bash
docker offload start
```

```bash
docker context show
```

Should print `offload-cloud` (or similar). Every subsequent `docker` command
targets the cloud engine.

### Phase 2 — Bring everything up

```bash
docker compose down --remove-orphans
```

Clean slate. Kills any half-built state from prior attempts.

```bash
docker compose up -d --build
```

Takes 1-2 minutes on first run (image pulls + backend build).

### Phase 3 — Verify

```bash
docker compose ps
```

You should see **8 services in `Up` state**: backend, demo-client, postgres,
pgadmin, kafka, kafka-ui, mock-inventory, aws.

If `backend` shows `Exited`, check its logs:

```bash
docker compose logs backend --tail 30
```

Most common: postgres race (backend connected before postgres was ready).
Fix: `docker compose restart backend`.

DNS check — does demo-client see backend?

```bash
docker compose exec demo-client getent hosts backend
```

Expected: `172.X.X.X backend`. Empty means the network setup broke — repeat
the `down --remove-orphans` + `up -d --build` cycle.

API check — does backend serve products from inside the network?

```bash
docker compose exec backend node -e "fetch('http://localhost:3000/api/products').then(r=>r.text()).then(console.log).catch(e=>console.error('ERR:',e.message))"
```

Expected: `[]`.

Frontend-to-backend reachability check:

```bash
docker compose exec demo-client node -e "fetch('http://backend:3000/api/products').then(r=>r.text()).then(console.log).catch(e=>console.error('ERR:',e.message))"
```

Expected: `[]`.

### Phase 4 — Browser test

Open `http://localhost:5173` in your Mac browser (Offload tunnels the port
back automatically). Click **Refresh catalog** — should show an empty list,
not the "error occurred" message. Click **Create product**, fill in
name/description/12-digit UPC/price, submit. The product should appear.

Verify persistence:

```bash
docker compose exec postgres psql -U postgres -d catalog -c "SELECT id, name, upc FROM products;"
```

### Phase 5 — Iterate on backend code

Since we're using `target: final` (production image, no source bind mount),
hot reload doesn't work. Apply backend code changes with:

```bash
docker compose up -d --build backend
```

~10-15 seconds per change.

### Phase 6 — Teardown

```bash
docker compose down --remove-orphans
docker offload stop
docker context show
```

`docker context show` should return to `default` after Offload stops.

---

## Restore local-dev when finished

```bash
[ -f .env.localdev ] && mv .env.localdev .env
rm compose.override.yaml
```

Then `npm run dev` works as the repo originally intended.

---

## Quick reference — common failures

| Symptom | Cause | Fix |
|---|---|---|
| `docker compose ps backend` empty | Override has `networks: external: true`, network got destroyed | Remove networks block from override, `down --remove-orphans` + `up --build` |
| Backend exits with `ECONNREFUSED 127.0.0.1:5432` | Backend reading `.env`'s `PGHOST=localhost` | Blank `.env`, ensure override sets `PGHOST: postgres` |
| `EAI_AGAIN backend` in demo-client logs | Backend isn't on the network (because it isn't running) | Check `docker compose ps -a` for backend status |
| `Cannot find module '/usr/local/app/src/index.js'` | Used `target: dev` which doesn't COPY src | Change override to `target: final` |
| `Mounting <hash> is not allowed` | Stale container with bind-mount spec, or watch sync attempted | `docker compose down --volumes --remove-orphans`, recreate |
| Browser shows "error occurred while fetching catalog" | Vite proxy not using `VITE_BACKEND_URL` (was started before env var arrived) | `docker compose restart demo-client` |
| Port already allocated on host | Another container or Offload reservation holds that host port | Use a different host-side port (we picked 3005 to avoid 3000) |

---

## What this exercise teaches

When you move a Compose stack to a remote engine, every assumption about
*"the engine is on the same host as my code"* breaks:

- Bind mounts assume shared filesystem → they fail
- `host.docker.internal` assumes the host is your laptop → it's now the cloud
- Native processes (`npm run dev`) assume containerised services on the same
  host → the network is now split
- `localhost` from inside a container means the container's own loopback →
  rarely what you actually want

The lessons generalise to any remote-engine scenario: SSH-based remote
contexts, build farms, swarm/k8s, GitHub Codespaces. Treat the engine as
its own host, and write your compose files so they don't depend on shared
filesystem or shared localhost assumptions.

The bug that hurt most: env var name mismatches that fall back to defaults
silently (`PGHOST` defaults to `localhost` which from inside a container is
the container itself) rather than erroring out loudly. Postgres connection
strings should be explicit, with no localhost-defaulting safety net.
