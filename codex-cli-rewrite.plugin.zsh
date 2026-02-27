# oh-my-zsh plugin: codex-cli-rewrite
# Rewrites natural-language shell intent in the current command buffer
# into a concrete shell command via `codex exec`.

: "${CODEX_CLI_REWRITE_KEY:=^I}"
: "${CODEX_CLI_REWRITE_MODEL:=}"

_codex_cli_rewrite_widget() {
  emulate -L zsh
  setopt pipefail

  if ! command -v codex >/dev/null 2>&1; then
    zle -M "codex-cli-rewrite: 'codex' command not found"
    return 1
  fi

  local user_input="$BUFFER"
  if [[ -z "${user_input//[[:space:]]/}" ]]; then
    zle -M "codex-cli-rewrite: command line is empty"
    return 0
  fi

  local tmp_out tmp_err prompt model_args response command
  tmp_out="$(mktemp "${TMPDIR:-/tmp}/codex-cli-rewrite.XXXXXX.out")" || return 1
  tmp_err="$(mktemp "${TMPDIR:-/tmp}/codex-cli-rewrite.XXXXXX.err")" || {
    rm -f -- "$tmp_out"
    return 1
  }

  prompt=$(cat <<PROMPT
Convert the following natural language shell request into exactly one executable shell command.
Return only the command text, with no markdown, no backticks, no explanation, and no surrounding quotes.
If the input already appears to be a shell command, return a cleaned-up equivalent command.

Request:
${user_input}
PROMPT
)

  model_args=()
  if [[ -n "$CODEX_CLI_REWRITE_MODEL" ]]; then
    model_args=(--model "$CODEX_CLI_REWRITE_MODEL")
  fi

  if ! print -r -- "$prompt" | codex exec \
    --skip-git-repo-check \
    --sandbox read-only \
    --color never \
    "${model_args[@]}" \
    -o "$tmp_out" \
    - >"$tmp_err" 2>&1; then
    zle -M "codex-cli-rewrite: codex exec failed (run 'codex login')"
    rm -f -- "$tmp_out" "$tmp_err"
    return 1
  fi

  response="$(<"$tmp_out")"
  rm -f -- "$tmp_out" "$tmp_err"

  response="${response//$'\r'/}"
  response="${response//\`\`\`/}"
  response="${response//$'\n'/ }"
  response="${response##[[:space:]]#}"
  response="${response%%[[:space:]]#}"

  command="$response"
  command="${command#\`}"
  command="${command%\`}"

  if [[ -z "$command" ]]; then
    zle -M "codex-cli-rewrite: empty response"
    return 1
  fi

  BUFFER="$command"
  CURSOR=${#BUFFER}
  zle -M "codex-cli-rewrite: rewritten"
  zle redisplay
}

zle -N codex-cli-rewrite _codex_cli_rewrite_widget
bindkey "$CODEX_CLI_REWRITE_KEY" codex-cli-rewrite
