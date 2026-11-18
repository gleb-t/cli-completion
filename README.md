# codex-cli-rewrite (oh-my-zsh plugin)

Rewrite natural language on your shell command line into an executable CLI command with one shortcut.

Example:
- You type: `list all files older than a week`
- Press your shortcut (for example `Alt-r`)
- The line is rewritten to a command such as: `find . -type f -mtime +7`

## Requirements

- `zsh`
- [oh-my-zsh](https://ohmyz.sh)
- `curl` and `jq`
- An OpenAI-compatible chat completions endpoint (LiteLLM by default) and a token

The plugin sends one chat completions request per rewrite (about 1s with a small model).

## Install

1. Clone this repo into your oh-my-zsh custom plugins directory:

```bash
git clone <YOUR_REPO_URL> "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/codex-cli-rewrite"
```

2. In `~/.zshrc`, enable the plugin and bind a key explicitly:

```zsh
# API endpoint and token (defaults: $HARBOR_LITELLM_URL/v1 and $HARBOR_LITELLM_TOKEN)
# export CODEX_CLI_REWRITE_API_URL='https://<litellm-host>/v1'
# export CODEX_CLI_REWRITE_API_TOKEN='<token>'

# Optional model override (default: anthropic/claude-haiku-5-5)
# export CODEX_CLI_REWRITE_MODEL='anthropic/claude-haiku-5-5'
# Optional reasoning_effort, sent only when set
# export CODEX_CLI_REWRITE_EFFORT='low'

plugins+=(codex-cli-rewrite)

# Bind after plugin init (example: Alt-r)
bindkey '^[r' codex-cli-rewrite
# or: codex_cli_rewrite_bind '^[r'

# Example: Ctrl-\
# bindkey '^\\' codex-cli-rewrite
```

Note: the plugin does not auto-bind any key by default.

3. Reload shell:

```bash
exec zsh
```

## Usage

1. Type a natural-language request in the prompt.
2. Press your configured shortcut.
3. The current line is replaced with the generated shell command.
4. Press Enter to run it.

## Update

```bash
cd "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/codex-cli-rewrite"
git pull --ff-only
```

## Notes

- The rewrite is a plain chat completions call: no agent, no tools, nothing is executed.
- If the rewrite fails, check that the API URL and token are set and valid.
