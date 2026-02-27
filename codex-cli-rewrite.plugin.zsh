# oh-my-zsh plugin: codex-cli-rewrite
# Rewrites natural-language shell intent in the current command buffer
# into a concrete shell command via `codex exec`.

typeset -g CODEX_CLI_REWRITE_RESULT_FILE

: "${CODEX_CLI_REWRITE_KEY:=^I}"
: "${CODEX_CLI_REWRITE_MODEL:=}"
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
  local prompt tmp_out tmp_err response command
  local -a model_args

  tmp_out="$(mktemp "${TMPDIR:-/tmp}/codex-cli-rewrite.out.XXXXXX")" || return 1
  tmp_err="$(mktemp "${TMPDIR:-/tmp}/codex-cli-rewrite.err.XXXXXX")" || {
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
    rm -f -- "$tmp_out" "$tmp_err"
    return 1
  fi

  response="$(<"$tmp_out")"
  rm -f -- "$tmp_out" "$tmp_err"

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

  if ! command -v codex >/dev/null 2>&1; then
    _prompt_msg "codex-cli-rewrite: 'codex' command not found"
    return 1
  fi

  local result
  result="$(_codex_cli_rewrite_spinner "$BUFFER")"

  [ -z "$result" ] && _prompt_msg "codex-cli-rewrite: rewrite failed (run 'codex login')" && return

  zle reset-prompt
  BUFFER="$result"
  CURSOR=${#BUFFER}
}

zle -N codex-cli-rewrite codex_cli_rewrite_widget
bindkey "$CODEX_CLI_REWRITE_KEY" codex-cli-rewrite
