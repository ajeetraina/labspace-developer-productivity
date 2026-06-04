# Step 7: Building a Product Catalog Team

In Step 6 you learned how sub-agents let a coordinator delegate work to
specialists. Now let's put that to work on a realistic business problem: managing
a **product catalog** for an e-commerce store.

We'll build a small team where a coordinator delegates to three specialists, uses
the pre-configured MCP Gateway from Step 4 for web research, and finally connects
to a live product catalog system over its API.

## The team

- **`catalog_coordinator`** — receives the request, breaks it down, and delegates
- **`market_research_agent`** — competitor pricing and market trends (uses the
  MCP Gateway: `duckduckgo` + `fetch`)
- **`customer_match_agent`** — maps products to customer segments (reads files)
- **`catalog_management_agent`** — reads and updates the catalog (filesystem + shell)

## Exercise: Create the catalog team

1. Create a `catalog.yaml` file with the following contents:

    ```yaml save-as=catalog.yaml
    version: "2"

    agents:
      catalog_coordinator:
        model: $$model$$
        description: Coordinates a product catalog team
        instruction: |
          You coordinate a product catalog team for an e-commerce store.
          Break each request down and delegate to the right specialist:
          - market_research_agent: competitor pricing and market trends
          - customer_match_agent: which customer segments a product fits
          - catalog_management_agent: read and update catalog files
          Delegate to the right agent for each task instead of doing it
          yourself, then summarize the results for the user.
        sub_agents:
          - market_research_agent
          - customer_match_agent
          - catalog_management_agent
        toolsets:
          - type: think
          - type: todo
            shared: true

      market_research_agent:
        model: $$model$$
        description: Researches competitor pricing and market trends
        instruction: |
          You research market data and competitor pricing.
          Use duckduckgo to search and fetch to read pages, then report
          concise findings back to the coordinator with sources.
        toolsets:
          - type: mcp
            remote:
              url: http://mcp-gateway:8080
              transport_type: sse

      customer_match_agent:
        model: $$model$$
        description: Maps products to customer segments
        instruction: |
          You analyze products and recommend which customer segments they fit
          best. Read any catalog or customer files the coordinator points you
          to and return clear segment recommendations.
        toolsets:
          - type: filesystem
            tools: [read_file, read_multiple_files]
          - type: think

      catalog_management_agent:
        model: $$model$$
        description: Reads and updates the product catalog
        instruction: |
          You manage the product catalog files. Read existing entries, create
          new ones, and make targeted edits. Confirm a file's structure before
          editing it.
        toolsets:
          - type: filesystem
          - type: shell
    ```

    > [!NOTE]
    > There is no `root` agent in this file, so you must tell Docker Agent which
    > agent to start with using `--agent`. Also notice every sub-agent has a
    > `description` — this is what the coordinator's model uses to decide which
    > agent to `transfer_task` to.

2. Run the team, starting from the coordinator:

    ```bash
    docker agent run catalog.yaml --agent catalog_coordinator
    ```

3. Give it a task that needs all three specialists so you can watch the handoffs:

    ```console
    I'm launching a line of insulated stainless steel water bottles. Research what
    competitors charge, create a starter catalog file (catalog.json) with 3 SKUs and
    suggested prices, and tell me which customer segment each SKU is aimed at.
    ```

    The coordinator will transfer research to `market_research_agent`, file
    creation to `catalog_management_agent`, and segmentation to
    `customer_match_agent`, then summarize the result for you.

4. Exit the agent with `Ctrl+C`.

## Connecting to your own product catalog system

So far the team can read local files and search the web, but a real store keeps
its catalog in a system with an API. The `api` toolset turns HTTP endpoints into
typed tools the agent can call directly. Let's give the management agent live
read access to a catalog service.

1. Update `catalog_management_agent` in your `catalog.yaml` to add the `api`
   toolset:

    ```yaml save-as=catalog.yaml
    version: "2"

    agents:
      catalog_coordinator:
        model: $$model$$
        description: Coordinates a product catalog team
        instruction: |
          You coordinate a product catalog team for an e-commerce store.
          Break each request down and delegate to the right specialist:
          - market_research_agent: competitor pricing and market trends
          - customer_match_agent: which customer segments a product fits
          - catalog_management_agent: read and update catalog data
          Delegate to the right agent for each task instead of doing it
          yourself, then summarize the results for the user.
        sub_agents:
          - market_research_agent
          - customer_match_agent
          - catalog_management_agent
        toolsets:
          - type: think
          - type: todo
            shared: true

      market_research_agent:
        model: $$model$$
        description: Researches competitor pricing and market trends
        instruction: |
          You research market data and competitor pricing.
          Use duckduckgo to search and fetch to read pages, then report
          concise findings back to the coordinator with sources.
        toolsets:
          - type: mcp
            remote:
              url: http://mcp-gateway:8080
              transport_type: sse

      customer_match_agent:
        model: $$model$$
        description: Maps products to customer segments
        instruction: |
          You analyze products and recommend which customer segments they fit
          best. Use the catalog tools to look up live product data, then
          return clear segment recommendations.
        toolsets:
          - type: think

      catalog_management_agent:
        model: $$model$$
        description: Reads and updates the product catalog
        instruction: |
          You manage the product catalog. Always use list_products and
          get_product to read live data from the catalog system before you
          answer or edit anything.
        toolsets:
          - type: filesystem
          - type: api
            api_config:
              name: list_products
              endpoint: http://catalog-system:8000/products
              method: GET
              instruction: List products, optionally filtered by category
              args:
                category:
                  type: string
                  description: Optional category filter
          - type: api
            api_config:
              name: get_product
              endpoint: http://catalog-system:8000/products
              method: GET
              instruction: Get a single product by id
              args:
                id:
                  type: string
                  description: Product id
              required: [id]
    ```

    > [!NOTE]
    > Replace `http://catalog-system:8000/products` with your catalog service's
    > real base URL. For GET requests the `args` are sent as query parameters
    > (`?category=...`). If the API needs authentication, add a `headers` block,
    > for example `headers: { Authorization: "Bearer ${CATALOG_TOKEN}" }`, and
    > export `CATALOG_TOKEN` before running. Each endpoint is its own
    > `- type: api` block with one `api_config`.

2. Run the team again:

    ```bash
    docker agent run catalog.yaml --agent catalog_coordinator
    ```

3. Ask it something that reads live catalog data:

    ```console
    Look up the product with id SKU-123 in the catalog and tell me which
    customer segment it's aimed at and how its price compares to competitors.
    ```

    The coordinator pulls the product through `catalog_management_agent`'s
    `get_product` tool, asks `market_research_agent` to compare pricing, and has
    `customer_match_agent` recommend a segment.

4. Exit the agent with `Ctrl+C`.

> [!TIP]
> If your catalog lives in a database instead of behind an API, you don't need
> the `api` toolset at all — enable a database MCP server (for example
> `postgres`) in the gateway and the agents reach it through the same
> `http://mcp-gateway:8080` connection they already use.

## Next Steps

In the final step, we'll wrap up what you've learned and explore where to go next.
