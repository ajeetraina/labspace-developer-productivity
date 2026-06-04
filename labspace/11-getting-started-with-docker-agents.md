# Step 2: Getting Started with Docker Agent

## Install Docker Agent

1. Run the following commands to install Docker Agent into your lab environment:

    ```bash
    # Download the latest Docker Agent Linux binary
    curl -L -o /tmp/docker-agent https://github.com/docker/docker-agent/releases/latest/download/docker-agent-linux-amd64

    # Install as a Docker CLI plugin
    mkdir -p ~/.docker/cli-plugins
    mv /tmp/docker-agent ~/.docker/cli-plugins/docker-agent

    # Move it to a location in your PATH
    chmod +x ~/.docker/cli-plugins/docker-agent
    ```

2. Once the install is completed, verify it by checking the version information:

    ```bash
    docker agent version
    ```

    You should see output showing the Docker Agent version.


## API setup

In order to complete this lab, you will need an API key from one of the following providers:

::variableSetButton[Use OpenAI]{variables="provider=openai,model=openai/gpt-5-nano,modelShort=gpt-5-nano"}

::variableSetButton[Use Anthropic]{variables="provider=anthropic,model=anthropic/claude-sonnet-4-6,modelShort=claude-sonnet-4-6"}

::variableSetButton[Use Gemini]{variables="provider=gemini,model=google/gemini-2.5-flash,modelShort=gemini-2.5-flash"}

&nbsp;

:::conditionalDisplay{variable="provider" requiredValue="openai"}
### OpenAI configuration

::variableDefinition[openaikey]{prompt="Enter your OpenAI API key (or leave blank if not using OpenAI)"}

```bash
export OPENAI_API_KEY=$$openaikey$$
```
:::


:::conditionalDisplay{variable="provider" requiredValue="anthropic"}
### Anthropic configuration

::variableDefinition[anthropickey]{prompt="Enter your Anthropic API key (or leave blank if not using Anthropic)"}

```bash
# For Anthropic models (if you provided an Anthropic key)
export ANTHROPIC_API_KEY=$$anthropickey$$
```
:::


:::conditionalDisplay{variable="provider" requiredValue="gemini"}
### Gemini configuration

::variableDefinition[googlekey]{prompt="Enter your Google/Gemini API key (or leave blank if not using Google)"}

```bash
export GOOGLE_API_KEY=$$googlekey$$
```
:::


## Writing your First Agent

Let's create the simplest possible agent. 

1. Create a file named `basic_hello.yaml` with the following contents:

    ```yaml save-as=basic_hello.yaml
    agents:
      root:
        model: $$model$$
        instruction: You talk like a pirate
    ```

2. Run this amazing agent using the following command:

    ```bash
    docker agent run basic_hello.yaml
    ```

3. Ask your agent a simple question to see it answer in pirate speak:

    ```console
    Give me an interesting and lesser-known fact about Docker
    ```

4. To exit the agent's interface, press `Ctrl+C`.


## Next Steps

In Step 3, we'll dive deeper into agent configuration and explore the powerful built-in tools that Docker Agent provides for file operations, web browsing, and more.
