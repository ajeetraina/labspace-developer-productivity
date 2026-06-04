# Step 4: MCP (Model Context Protocol)

[MCP](https://modelcontextprotocol.io/) is an open-source standard for
connecting AI applications to external systems.

MCP is a standardized protocol that gives agents access to different MCP servers containing tools (and much more - we encourage you to read the specification).


## Pre-configured MCP Gateway

In this Labspace, we've pre-configured an MCP Gateway with the following servers:

- **fetch** - Fetch and read web pages
- **duckduckgo** - Search the web
- **context7** - Access library documentation

Let's verify the MCP Gateway is running:

```bash
curl http://mcp-gateway:8080/health -v
```

If it's up and running, you should see a `200 OK` response.

## Using the Fetch MCP Server

1. Create an agent that can fetch and summarize web pages in a file named `fetch_agent.yaml`:

    ```yaml save-as=fetch_agent.yaml
    version: "2"

    agents:
      root:
        model: $$model$$
        instruction: Summarize URLs for users. Use the fetch tool to retrieve web pages.
        toolsets:
          - type: mcp
            remote:
              url: http://mcp-gateway:8080
              transport_type: sse
    ```

2. Start the agent:

    ```bash
   docker agent run fetch_agent.yaml
    ```

3. Ask it to fetch web content and summarize it: 

    ```console
    Fetch docker.com and summarize what Docker's main focus is based on its website
    ```

    You will see the agent calling the `fetch` tool from the MCP server!

4. Exit the agent with `Ctrl+C`

## Using the DuckDuckGo MCP Server

The same gateway provides web search capabilities:

1. Create a search agent in a file named `search_agent.yaml` with the following contents:

    ```yaml save-as=search_agent.yaml
    version: "2"

    agents:
      root:
        model: $$model$$
        instruction: |
          You are a research assistant. 
          Use the duckduckgo search tool to find information.
          Always cite your sources.
        toolsets:
          - type: mcp
            remote:
              url: http://mcp-gateway:8080
              transport_type: sse
    ```

2. Run the agent:

    ```bash
    docker agent run search_agent.yaml
    ```

3. Ask it to search for recent news about containers: 

    ```console
    Search for the latest news about Docker containers
    ```

4. Exit the agent with `Ctrl+C`

## Using Context7 for Documentation

Context7 provides up-to-date documentation for libraries and frameworks.

1. Create a docs agent by defining a `docs_agent.yaml` file with the following contents:

    ```yaml save-as=docs_agent.yaml
    version: "2"

    agents:
      root:
        model: $$model$$
        instruction: |
          You are a documentation expert.
          Use context7 to find accurate, up-to-date documentation for any library.
        toolsets:
          - type: mcp
            remote:
              url: http://mcp-gateway:8080
              transport_type: sse
    ```

2. Start the agent:

    ```bash
    docker agent run docs_agent.yaml
    ```

3. Ask it a question that will reference the documentation: 

    ```console
    How do I set up a basic Express.js server? Use context7 to get the latest documentation.
    ```

4. Exit the agent with `Ctrl+C`


## Enhancing Our Developer Agent

Let's combine everything we've learned to create a powerful developer agent.

1. Create a new `developer.yaml` that adds all of these additional tools and capabilities:

    ```yaml save-as=developer.yaml
    version: "2"

    agents:
      root:
        model: $$model$$
        instruction: |
          You are an amazing developer.
          Use available tools to:
          - Search for information (duckduckgo)
          - Fetch documentation (fetch, context7)
          - Read and write files (filesystem)
          - Run commands (shell)
          - Track your tasks (todo)
        add_environment_info: true
        add_date: true
        toolsets:
          - type: todo
          - type: shell
          - type: filesystem
          - type: mcp
            remote:
              url: http://mcp-gateway:8080
              transport_type: sse
    ```

2. Run this agent:

    ```bash
    docker agent run developer.yaml
    ```

3. Ask this:

    ```console
    Create a directory "server" and write a Node.js Express server with TypeScript. 
    The server should be a key-value store with GET, PUT, and DELETE endpoints.
    Use context7 to get the latest Express.js documentation.
    ```

    The agent will:
    1. Use context7 to fetch Express.js documentation
    2. Create the directory structure
    3. Write the TypeScript server code
    4. Set up the necessary configuration files

4. Exit the agent with `Ctrl+C`


## Next Steps

In Step 5, we'll learn how to share your agents with others using Docker Registry.
