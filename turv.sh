XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
# Public API config
TURV_CONFIG_FORMAT="${TURV_CONFIG_FORMAT:-yaml}" # Default: YAML
TURV_APPROVAL_FILE="$XDG_STATE_HOME/turv/approved.${TURV_CONFIG_FORMAT}"
TURV_ENV_FILE="${TURV_ENV_FILE:-.envrc}"
TURV_DEBUG="${TURV_DEBUG}"
TURV_QUIET="${TURV_QUIET}"
TURV_ASSUME_YES="${TURV_ASSUME_YES}" # if you also pipe curl to sudo shells
TURV_VIEWER="${TURV_VIEWER:-cat}"

# internal
TURV_ACTIVE_ENV=""

_debug() {
  if [[ -n "$TURV_DEBUG" ]]; then
    echo "\033[3;36mturv:\033[0m \033[1;36m[DBG]\033[0m\033[10;36m $1\033[0m"
  fi
}

_print() {
  if [[ -z "$TURV_QUIET" ]]; then
    echo "\033[3;37mturv:\033[0m \033[1;37m[LOG]\033[0m\033[10;37m $1\033[0m"
  fi
}

_error() {
  >&2 echo "\033[3;91mturv:\033[0m \033[1;91m[ERR]\033[0m\033[10;91m $1\033[0m"
}

# Select appropriate parsing commands
case "$TURV_CONFIG_FORMAT" in
json)
  CONFIG_TOOL="jq"
  ;;
yaml | toml)
  CONFIG_TOOL="yq"
  ;;
*)
  _error "Unsupported config format: $TURV_CONFIG_FORMAT"
  return 1
  ;;
esac

for cmd in "$CONFIG_TOOL" "$TURV_VIEWER"; do
  command -v "$cmd" &>/dev/null || {
    _error "Missing required command: $cmd"
    return 1
  }
done

if [[ ! -f "$TURV_APPROVAL_FILE" ]]; then
  _debug "Approval file not found, creating it..."
  mkdir -p "$(dirname "$TURV_APPROVAL_FILE")"

  case "$TURV_CONFIG_FORMAT" in
  json) echo '{"approved_dirs": {}}' >"$TURV_APPROVAL_FILE" ;;
  yaml) echo "approved_dirs: {}" >"$TURV_APPROVAL_FILE" ;;
  toml)
    _error "toml not supported at this moment"
    return 1
    ;;
  esac
fi

_call_func() {
  declare -f -F "$1" &>/dev/null && "$1"
}

_set_approval() {
  local dir="${1}"
  local approval=${2:-"false"}
  local hash
  hash=$(sha256sum "$TURV_ENV_FILE" | awk '{print $1}')

  local state="{\"approved\": "$approval", \"hash\": \"$hash\"}"
  local jsonQuery=".approved_dirs[\"$dir\"] = $state"

  local tmp_file="${TURV_APPROVAL_FILE}.tmp"

  echo "$jsonQuery"
  $CONFIG_TOOL "$jsonQuery" "$TURV_APPROVAL_FILE" \
    >"$tmp_file" && mv "$tmp_file" "$TURV_APPROVAL_FILE"

}

_get_approval_state() {
  local dir="${1}"
  local jsonQuery=".approved_dirs[\"$dir\"].approved // -1"

  local state
  state=$($CONFIG_TOOL "$jsonQuery" "$TURV_APPROVAL_FILE")

  echo "$state"
}

_get_approval_hash() {
  local dir="${1}"
  local jsonQuery=".approved_dirs[\"$dir\"].hash // -1"

  local hash
  hash=$($CONFIG_TOOL "$jsonQuery" "$TURV_APPROVAL_FILE")

  echo "$hash"
}

_reset_approval() {
  local dir="${1-$PWD}"
  local tmp_file="${TURV_APPROVAL_FILE}.tmp"

  local jsonQuery="del(.approved_dirs[\"$dir\"])"

  $CONFIG_TOOL "$jsonQuery" "$TURV_APPROVAL_FILE" \
    >"$tmp_file" && mv "$tmp_file" "$TURV_APPROVAL_FILE"
}

_check_directory_state() {
  _debug "Checking approval for directory: $PWD"

  # Ensure the approval file exists
  [[ ! -f "$TURV_APPROVAL_FILE" ]] && _error "Approval file not found." && 106

  local is_approved
  local last_hash

  is_approved=$(_get_approval_state "$PWD")
  last_hash=$(_get_approval_hash "$PWD")

  _debug "is_approved: $is_approved, last_hash: $last_hash"

  if [[ "$is_approved" == "-1" ]]; then
    _debug "Directory not found in '$TURV_APPROVAL_FILE'"
    return 10
  fi

  # Check if directory is approved
  if [[ ! "$is_approved" || -z "$is_approved" ]]; then
    _print "Directory '$PWD' is not approved."
    return 20
  fi

  file_hash=$(sha256sum "$TURV_ENV_FILE" | awk '{print $1}')
  _debug "$TURV_ENV_FILE -> $file_hash"
  if [[ -z "$last_hash" || "$last_hash" != "$file_hash" ]]; then
    _print "File has changed."
    return 30
  fi

  _debug "Directory '$PWD' is approved."
  return 40
}

_prompt_for_approval() {
  if [[ -n "$TURV_ASSUME_YES" ]]; then
    _debug "Assume yes"
    _set_approval "$PWD" true
    return 0
  fi

  bat "$PWD/$TURV_ENV_FILE" -lbash --style=snip,numbers,header
  echo -n "\033[3mturv:\033[0m Source environment for \033[35;1m'$PWD'\033[0m? [y/N] "
  read -r response

  case "$response" in
  [Yy]*)
    _set_approval "$PWD" true
    return 0
    ;;
  *)
    _set_approval "$PWD" false
    return 1
    ;;
  esac
}

_turv_hook() {
  _debug "$TURV_ACTIVE_ENV -> $PWD"

  # Check if moving up (not into a subdirectory)
  if [[ -n "$TURV_ACTIVE_ENV" && ! "$PWD" =~ ^"$TURV_ACTIVE_ENV"(/|$) ]]; then
    _print "Unloading..."

    _call_func _unload

    unset -f _load &>/dev/null
    unset -f _unload &>/dev/null

    unset TURV_ACTIVE_ENV
  fi

  if [[ -f "$PWD/$TURV_ENV_FILE" && -z "$TURV_ACTIVE_ENV" ]]; then
    _check_directory_state
    local exit_code=$?

    _debug "_should_ask_to_load: $exit_code"
    case $exit_code in
    40) ;;
    20)
      _print "turv not allowed"
      return
      ;;
    10 | 30)
      _prompt_for_approval || return
      ;;
    esac

    _print "Loading $TURV_ENV_FILE"

    source "$PWD/$TURV_ENV_FILE" &>/dev/null

    _call_func _load

    TURV_ACTIVE_ENV="$PWD"
    export TURV_ACTIVE_ENV
  fi
}

# public api
turv_load() {
  local dir=${1-$PWD}

  _print "Loading $TURV_ENV_FILE"

  source "$dir/$TURV_ENV_FILE" &>/dev/null

  _call_func _load

  TURV_ACTIVE_ENV="$dir"
  export TURV_ACTIVE_ENV
}

turv_reset_directory() {
  local dir=${1-$PWD}

  _debug "Resetting '$dir'"

  _reset_approval "$dir"
}

# zsh init
typeset -ag precmd_functions

if [[ -z ${precmd_functions[_turv_hook]} ]]; then
  precmd_functions+=_turv_hook
fi

# vim: ft=bash ts=2 sts=2 sw=2 et
