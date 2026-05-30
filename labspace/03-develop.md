# Lab 3 · Develop

This is where the inner loop really comes alive. You'll bring up the full environment, create products through the web UI, watch them flow into Postgres and Kafka, **discover a bug**, and **fix it live** — all without leaving your containerized environment.

## Clone the application

Labs 3–6 use the **Catalog Service** sample app. Clone it into your workspace:

```bash
git clone https://github.com/dockersamples/catalog-service-node.git
```

Then move into the project directory — every command in Labs 3–6 runs from here:

```bash
cd catalog-service-node
```

## Bring up the environment

Start all the backing services (Postgres, Kafka, LocalStack, WireMock, pgAdmin, Kafka UI):

```bash
docker compose up -d
```

Confirm everything is healthy:

```bash
docker compose ps
```

> 📝 **Optional — workshop demo prep.** If you're running this as a guided demo, the repo includes a prep script that seeds the bug you'll fix below:
>
> ```bash no-run-button
> cd demo/sdlc-e2e && ./setup.sh
> ```
>
> The `setup.sh` script creates a per-participant demo branch, cleans the working tree, pulls the latest code, applies a demo patch, runs `npm install`, and pre-pulls all the container images so the workshop starts instantly. Importantly, the patch **deliberately removes** the `upc: product.upc,` line from `src/services/ProductService.js` — that's the bug you'll fix below. If you skip the script, you can still follow along; just be aware the UPC line may already be present.

## Start the API service

With the dependencies running, start the application itself in dev mode (live reload is enabled):

```bash
cd ../../
npm install
```

```bash
npm run dev
```

Keep the terminal up and running. 
Once it's up, open the **Web Client** tab (or :tabLink[open it here]{href="http://localhost:5173" title="Web Client"}) at [http://localhost:5173](http://localhost:5173) and **create a few products**.

## Verify the data landed in Postgres

Open the **pgAdmin** tab at [http://localhost:5050](http://localhost:5050) and confirm the products exist. Use the password `postgres` to log in.

You can also check directly from the database container:

```bash
cd ~/project/catalog-service-node
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
