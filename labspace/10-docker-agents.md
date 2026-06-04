# Introduction

# Building Agents with Docker Agent - Workshop

Welcome to this hands-on workshop on building intelligent agents using Docker Agent!
This workshop will take you from basic agent concepts to building sophisticated
multi-agent teams that can handle complex real-world tasks.

## What is Docker Agent?

Docker Agent is a powerful framework for building and orchestrating AI agents. Unlike
simple chatbots, Docker Agent can:

- **Take Actions**: Use tools to interact with files, run commands, browse the
  web, and more
- **Work in Teams**: Coordinate with specialized sub-agents for complex projects
- **Remember Context**: Maintain persistent memory across conversations
- **Think and Plan**: Use structured reasoning to solve complex problems
- **Integrate Anywhere**: Connect to external services via the Model Context
  Protocol (MCP)

## What's Pre-Configured in This Labspace

This Labspace comes with everything you need to get started:

| Service | URL | Description |
|---------|-----|-------------|
| **MCP Gateway** | `http://labspace-mcp-gateway:8080` | Pre-configured with fetch, duckduckgo, and context7 servers |

## Prerequisites

Before starting this workshop, you should have an API key to a model provider. The following providers are supported:

- OpenAI 
- Anthropic
- Google (for Gemini models)

Additionally, this lab will make use of Docker's MCP Gateway, which should already be up and running.

Verify it's running by running the following command:

```bash
# Check MCP Gateway
curl http://labspace-mcp-gateway:8080/sse
```

If the command returns successfully, you're ready to go!


## Workshop Overview

In this workshop we will learn the basics of creating agents and teams of
agents. How to run them and how to share them.

While we learn how to use Docker Agent we will focus on making a coding agent.

By the end of this workshop you should have everything you need to make your own
agents that do things for you.

## What You'll Learn

| Step | Topic | Description |
|------|-------|-------------|
| 2 | Getting Started | Create your first agent |
| 3 | Built-in Tools | File operations, shell commands, memory, and todo tracking |
| 4 | MCP Integration | Connect to external services (fetch, search, documentation) |
| 5 | Sharing Agents | Push and pull agents via Docker Hub |
| 6 | Sub-agents | Build multi-agent teams with specialized roles |
| 7 | Model Runner | Run local AI models on your local machine (reference only) |
| 8 | Conclusion | Next steps and advanced topics |

