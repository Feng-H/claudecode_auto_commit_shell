# Claude Code Auto Commit

## Project Overview

**Claude Code Auto Commit** is a shell-based utility designed to automatically generate and execute `git commit` commands when a Claude Code session ends. It leverages the Anthropic Claude API to analyze code changes (`git diff`) and generate semantic, convention-compliant commit messages (supporting Chinese and English).

### Key Features
*   **Automated Hooks**: Triggered automatically upon session exit.
*   **Intelligent Analysis**: Uses Claude Sonnet (via API) to understand code context.
*   **Auto-Initialization**: Can automatically `git init` non-repositories.
*   **Safety First**: Includes basic security checks for sensitive information in commits.
*   **Configurable**: Supports custom prompts, API endpoints (proxies), and languages.

## Directory Overview

*   **`auto_commit_handler.sh`**: The core script logic. It handles git status checks, diff extraction, API communication (via an inline Node.js script), and the final commit execution.
*   **`install.sh`**: Automated installation script that sets up the directory structure (`~/.claude/scripts`), copies files, and configures the Claude Code `settings.json` hook.
*   **`uninstall.sh`**: Removes the scripts, configuration, and hook entries.
*   **`ac_config.env`**: Environment configuration file for customizing behavior (e.g., language, auto-init preference).
*   **`commit_prompt_zh.txt`**: The prompt template used to instruct the LLM on how to format the commit message.

## Building and Running

Since this is a script-based tool, "building" effectively means installation.

### Prerequisites
*   **Git**: Required for version control operations.
*   **Node.js**: Required by `auto_commit_handler.sh` to execute the inline API call script.
*   **jq**: Required for JSON processing within the shell script.

### Installation
To install the tool into your local Claude Code environment:

```bash
bash install.sh
```

### Configuration
1.  **API Key**: You **must** set the `ANTHROPIC_API_KEY` environment variable in your shell profile (`~/.zshrc` or `~/.bashrc`).
    ```bash
    export ANTHROPIC_API_KEY="sk-..."
    ```
2.  **Settings**: Edit `~/.claude/ac_config.env` to change defaults:
    *   `COMMIT_LANGUAGE`: `zh-CN` (default) or `en`.
    *   `AUTO_INIT`: `true` or `false`.
    *   `USE_CLAUDE_API`: Toggle API usage vs. local fallback.

### Manual Execution (Testing)
You can manually trigger the script to test its behavior without waiting for a session end:

```bash
~/.claude/scripts/auto_commit_handler.sh
```

## Development Conventions

*   **Scripting**: The project uses Bash for logic flow and Node.js for complex network/JSON tasks.
*   **Logging**: Debug logs are written to `~/.claude/ac_handler.log`.
*   **Security**: Sensitive information (keys, tokens) is filtered from logs.
*   **Fallback**: The script includes a "local fallback" mode to generate simple commit messages if the API call fails or is disabled.
