# oh-my-zsh plugin: codex-cli-rewrite
# Rewrites natural-language shell intent in the current command buffer
# into a concrete shell command via an OpenAI-compatible chat completions API
# (LiteLLM by default). Spinner/widget flow adapted from:
# https://github.com/loiccoyle/zsh-github-copilot

typeset -g CODEX_CLI_REWRITE_RESULT_FILE

: "${CODEX_CLI_REWRITE_MODEL:=anthropic/claude-haiku-5-5}"
# Optional reasoning_effort (minimal|low|medium|high). Empty = not sent.
: "${CODEX_CLI_REWRITE_EFFORT:=}"
# API URL/token are resolved at call time; they default to HARBOR_LITELLM_URL/TOKEN.
: "${CODEX_CLI_REWRITE_RESULT_FILE:=/tmp/zsh_codex_cli_rewrite_result}"

_codex_cli_rewrite_trim() {
  : "${1#"${1%%[![:space:]]*}"}"
  : "${_%"${_##*[![:space:]]}"}"
  printf '%s\n' "$_"
}

_codex_cli_rewrite_generate() {
  emulate -L zsh
  setopt pipefail

  local user_input="$1"
  local api_url="${CODEX_CLI_REWRITE_API_URL:-${HARBOR_LITELLM_URL%/}/v1}"
  local api_token="${CODEX_CLI_REWRITE_API_TOKEN:-$HARBOR_LITELLM_TOKEN}"
  local system_prompt body response command

  [[ -n "$api_token" && "$api_url" != "/v1" ]] || return 1

  system_prompt="Translate the user's request into exactly one ${SHELL:t} command for macOS. \
Output only the command: no markdown, no backticks, no explanation, no surrounding quotes. \
If the input is already a command, return a cleaned-up equivalent."

  body="$(jq -n \
    --arg model "$CODEX_CLI_REWRITE_MODEL" \
    --arg effort "$CODEX_CLI_REWRITE_EFFORT" \
    --arg sys "$system_prompt" \
    --arg user "$user_input" \
    '{model: $model, max_tokens: 500,
      messages: [{role: "system", content: $sys}, {role: "user", content: $user}]}
     + (if $effort != "" then {reasoning_effort: $effort} else {} end)')" || return 1

  response="$(print -r -- "$body" | curl -sS --fail -m 30 "$api_url/chat/completions" \
    -H "Authorization: Bearer $api_token" \
    -H "Content-Type: application/json" \
    --data-binary @- 2>/dev/null | jq -r '.choices[0].message.content // empty')" || return 1

  response="${response//$'\r'/}"
  response="${response//\`\`\`/}"
  response="${response//$'\n'/ }"
  response="$(_codex_cli_rewrite_trim "$response")"

  command="$response"
  command="${command#\`}"
  command="${command%\`}"

  if [[ -z "$command" ]]; then
    return 1
  fi

  print -r -- "$command"
}

_spinner() {
  local pid=$1
  local delay=0.1
  local spin='⣾⣽⣻⢿⡿⣟⣯⣷'

  cleanup() {
    kill "$pid" >/dev/null 2>&1
    tput cnorm >/dev/null 2>&1
  }
  trap cleanup SIGINT

  local i=0
  tput civis >/dev/null 2>&1
  while kill -0 "$pid" 2>/dev/null; do
    i=$(((i + 1) % ${#spin}))
    printf "  %s" "${spin:$i:1}" >&2
    sleep "$delay"
    printf "\b\b\b" >&2
  done
  printf "   \b\b\b" >&2
  tput cnorm >/dev/null 2>&1
  trap - SIGINT
}

_codex_cli_rewrite_spinner() {
  read -r < <(
    _codex_cli_rewrite_generate "$@" >|"$CODEX_CLI_REWRITE_RESULT_FILE" &
    echo $!
  )
  _spinner "$REPLY" >&2
  cat "$CODEX_CLI_REWRITE_RESULT_FILE"
}

_prompt_msg() {
  printf "\n%s\n\n" "$@"
  zle reset-prompt
}

codex_cli_rewrite_widget() {
  [ -z "$BUFFER" ] && return
  zle end-of-line

  if ! command -v jq >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    _prompt_msg "codex-cli-rewrite: needs 'curl' and 'jq'"
    return 1
  fi

  local result
  result="$(_codex_cli_rewrite_spinner "$BUFFER")"

  [ -z "$result" ] && _prompt_msg "codex-cli-rewrite: rewrite failed (check HARBOR_LITELLM_URL/TOKEN)" && return

  zle reset-prompt
  BUFFER="$result"
  CURSOR=${#BUFFER}
}

zle -N codex-cli-rewrite codex_cli_rewrite_widget

# Optional helper: bind the widget to a key sequence explicitly from ~/.zshrc
# Example: codex_cli_rewrite_bind '^[r'   # Alt-r
codex_cli_rewrite_bind() {
  local keyseq="$1"
  if [[ -z "$keyseq" ]]; then
    echo "usage: codex_cli_rewrite_bind '<keyseq>'" >&2
    return 1
  fi
  bindkey "$keyseq" codex-cli-rewrite
}
