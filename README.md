# codex-cli-rewrite (oh-my-zsh plugin)

Rewrite natural language on your shell command line into an executable CLI command with one shortcut.

Example:
- You type: `list all files older than a week`
- Press your shortcut (for example `Alt-r`)
- The line is rewritten to a command such as: `find . -type f -mtime +7`

## Requirements

- `zsh`
- [oh-my-zsh](https://ohmyz.sh)
- [`codex` CLI](https://github.com/openai/codex) installed and logged in (`codex login`)

This plugin uses your existing Codex login flow (no API keys).

## Install

1. Clone this repo into your oh-my-zsh custom plugins directory:

```bash
git clone <YOUR_REPO_URL> "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/codex-cli-rewrite"
```

2. In `~/.zshrc`, enable the plugin and bind a key explicitly:

```zsh
# Optional model override
# export CODEX_CLI_REWRITE_MODEL='gpt-5'

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
3. The current line is replaced with Codex's generated shell command.
4. Press Enter to run it.

## Update

```bash
cd "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/codex-cli-rewrite"
git pull --ff-only
```

## Notes

- The rewrite runs `codex exec` with `--sandbox read-only`.
- If rewrite fails, check authentication with:

```bash
codex login
```
