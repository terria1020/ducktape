#######################
# ~/.zsh/shell-agents-tmux.zsh
# ducktape — F2 attach/detach, F12 bound-session cycle

setopt PROMPT_SUBST

if ! command -v tmux &>/dev/null; then
  print "⚠️  ducktape: tmux을 찾을 수 없습니다. 설치 후 다시 시도하세요." >&2
  print "   brew install tmux" >&2
  return 0
fi

_DUCKTAPE_CONF="$HOME/.zsh/.ducktape-agent"
_DUCKTAPE_AGENT=$(cat "$_DUCKTAPE_CONF" 2>/dev/null || echo "claude")
_DUCKTAPE_GLOBAL_PARAMS_DIR="$HOME/.zsh"
_DUCKTAPE_BIND_FILE="$HOME/.zsh/.ducktape-bindings"
_DUCKTAPE_LEGACY_TAPING_FILE="$PWD/.ducktape-taping"

_ducktape_dir_hash() {
  local dir="${1:-$PWD}"
  print -n "$dir" | shasum | awk '{print $1}'
}

_ducktape_session_for_dir() {
  local dir="${1:-$PWD}"
  local hash=$(_ducktape_dir_hash "$dir")
  print "ducktape-${_DUCKTAPE_AGENT}-${hash:0:8}"
}

_ducktape_cmd_for_dir() {
  local dir="${1:-$PWD}"
  local agent
  case "$_DUCKTAPE_AGENT" in
    cursor) agent="agent" ;;
    *)      agent="$_DUCKTAPE_AGENT" ;;
  esac

  local gp lp
  gp=$(cat "$_DUCKTAPE_GLOBAL_PARAMS_DIR/.ducktape-params-${_DUCKTAPE_AGENT}" 2>/dev/null)
  lp=$(cat "$dir/.ducktape-params" 2>/dev/null)

  local cmd="$agent"
  [[ -n "$gp" ]] && cmd="$cmd $gp"
  [[ -n "$lp" ]] && cmd="$cmd $lp"
  print "$cmd"
}

_ducktape_bound_paths() {
  [[ -f "$_DUCKTAPE_BIND_FILE" ]] || return 0
  sed '/^$/d' "$_DUCKTAPE_BIND_FILE"
}

_ducktape_save_bound_paths() {
  local tmp="${_DUCKTAPE_BIND_FILE}.tmp.$$"
  mkdir -p "$_DUCKTAPE_GLOBAL_PARAMS_DIR" || return 1
  : > "$tmp" || return 1

  local entry
  for entry in "$@"; do
    [[ -n "$entry" ]] || continue
    print -r -- "$entry" >> "$tmp" || return 1
  done

  mv "$tmp" "$_DUCKTAPE_BIND_FILE"
}

_ducktape_bound_path_exists() {
  local target="$1"
  local entry
  while IFS= read -r entry; do
    [[ "$entry" == "$target" ]] && return 0
  done < <(_ducktape_bound_paths)
  return 1
}

_ducktape_prune_bound_paths() {
  local changed=1
  local kept=()
  local entry

  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    if [[ -d "$entry" ]]; then
      kept+=("$entry")
    else
      changed=0
    fi
  done < <(_ducktape_bound_paths)

  if (( ${#kept[@]} == 0 )); then
    rm -f "$_DUCKTAPE_BIND_FILE"
  else
    _ducktape_save_bound_paths "${kept[@]}" || return 1
  fi

  return $changed
}

_ducktape_attach_or_create_agent() {
  local dir="${1:-$PWD}"
  local session=$(_ducktape_session_for_dir "$dir")

  if tmux has-session -t "$session" 2>/dev/null; then
    BUFFER="tmux attach-session -t '$session'"
  else
    BUFFER="tmux new-session -d -s '$session' -c '$dir' $(_ducktape_cmd_for_dir "$dir") && tmux attach-session -t '$session'"
  fi
}

_ducktape_switch_or_create_agent() {
  local dir="$1"
  local session=$(_ducktape_session_for_dir "$dir")

  if tmux has-session -t "$session" 2>/dev/null; then
    tmux switch-client -t "$session"
  else
    tmux new-session -d -s "$session" -c "$dir" $(_ducktape_cmd_for_dir "$dir")
    tmux switch-client -t "$session"
  fi
}

ducktape-tmux-f2() {
  tmux detach-client
}

ducktape-tmux-f12() {
  _ducktape_prune_bound_paths >/dev/null

  local current_dir
  current_dir=$(tmux display-message -p "#{pane_current_path}" 2>/dev/null || print "")
  [[ -n "$current_dir" ]] || return 0

  local paths=()
  local entry
  while IFS= read -r entry; do
    [[ -n "$entry" ]] && paths+=("$entry")
  done < <(_ducktape_bound_paths)

  (( ${#paths[@]} > 0 )) || return 0

  local current_index=-1
  local i
  for (( i = 1; i <= ${#paths[@]}; i++ )); do
    if [[ "${paths[i]}" == "$current_dir" ]]; then
      current_index=$i
      break
    fi
  done

  if (( current_index == -1 )); then
    _ducktape_switch_or_create_agent "${paths[1]}"
    return 0
  fi

  if (( ${#paths[@]} == 1 )); then
    return 0
  fi

  local next_index=$(( current_index % ${#paths[@]} + 1 ))
  _ducktape_switch_or_create_agent "${paths[next_index]}"
}

_ducktape_f2_widget() {
  _ducktape_attach_or_create_agent "$PWD"
  zle accept-line
}

zle -N _ducktape_f2_widget

zmodload zsh/terminfo 2>/dev/null
if [[ -n "${terminfo[kf2]}" ]]; then
  bindkey -M emacs "${terminfo[kf2]}" _ducktape_f2_widget
  bindkey -M viins "${terminfo[kf2]}" _ducktape_f2_widget
fi
bindkey -M emacs $'\eOQ' _ducktape_f2_widget
bindkey -M viins $'\eOQ' _ducktape_f2_widget

ducktape-alias() {
  local candidates=()
  command -v claude  &>/dev/null && candidates+=(claude)
  command -v gemini  &>/dev/null && candidates+=(gemini)
  command -v codex   &>/dev/null && candidates+=(codex)
  command -v agent   &>/dev/null && candidates+=(cursor)

  if [[ ${#candidates} -eq 0 ]]; then
    print "✗ 설치된 에이전트 없음 (claude / gemini / codex / cursor)"
    return 1
  fi

  local selected
  if command -v fzf &>/dev/null; then
    selected=$(printf '%s\n' $candidates | fzf --prompt="에이전트 선택> " --height=10)
  else
    print "설치된 에이전트:"
    select agent in $candidates; do
      selected=$agent
      break
    done
  fi

  [[ -z "$selected" ]] && print "취소됨" && return 0

  print "$selected" > "$_DUCKTAPE_CONF"
  _DUCKTAPE_AGENT="$selected"
  print "✓ 에이전트 변경: $selected"
  print "  새 터미널 또는 'source ~/.zsh/shell-agents-tmux.zsh' 후 적용"
}

ducktape-taping() {
  local action="${1:---show}"

  case "$action" in
    bind)
      if ! _ducktape_bound_path_exists "$PWD"; then
        local paths=()
        local entry
        while IFS= read -r entry; do
          [[ -n "$entry" ]] && paths+=("$entry")
        done < <(_ducktape_bound_paths)
        paths+=("$PWD")
        _ducktape_save_bound_paths "${paths[@]}" || {
          print "✗ 바인드 저장 실패: $_DUCKTAPE_BIND_FILE"
          return 1
        }
        print "✓ 바인드 등록: $PWD"
      else
        print "✓ 이미 바인드됨: $PWD"
      fi

      if ! tmux has-session -t "$(_ducktape_session_for_dir "$PWD")" 2>/dev/null; then
        tmux new-session -d -s "$(_ducktape_session_for_dir "$PWD")" -c "$PWD" $(_ducktape_cmd_for_dir "$PWD") || {
          print "✗ 세션 생성 실패: $(_ducktape_session_for_dir "$PWD")"
          return 1
        }
        print "✓ 세션 생성: $(_ducktape_session_for_dir "$PWD")"
      fi

      rm -f "$_DUCKTAPE_LEGACY_TAPING_FILE"
      ;;
    unbind)
      local kept=()
      local removed=1
      local entry
      while IFS= read -r entry; do
        [[ -n "$entry" ]] || continue
        if [[ "$entry" == "$PWD" ]]; then
          removed=0
        else
          kept+=("$entry")
        fi
      done < <(_ducktape_bound_paths)

      if (( ${#kept[@]} == 0 )); then
        rm -f "$_DUCKTAPE_BIND_FILE"
      else
        _ducktape_save_bound_paths "${kept[@]}" || {
          print "✗ 바인드 저장 실패: $_DUCKTAPE_BIND_FILE"
          return 1
        }
      fi

      if (( removed == 0 )); then
        print "✓ 바인드 해제: $PWD"
      else
        print "✓ 바인드 없음: $PWD"
      fi
      ;;
    clear)
      rm -f "$_DUCKTAPE_BIND_FILE"
      print "✓ 전체 바인드 초기화"
      ;;
    --show|show)
      _ducktape_prune_bound_paths >/dev/null

      local paths=()
      local entry
      while IFS= read -r entry; do
        [[ -n "$entry" ]] && paths+=("$entry")
      done < <(_ducktape_bound_paths)

      if (( ${#paths[@]} == 0 )); then
        print "bindings: (없음)"
        return 0
      fi

      print "bindings:"
      local i marker session session_state
      for (( i = 1; i <= ${#paths[@]}; i++ )); do
        entry="${paths[i]}"
        marker=" "
        [[ "$entry" == "$PWD" ]] && marker="*"
        session=$(_ducktape_session_for_dir "$entry")
        if tmux has-session -t "$session" 2>/dev/null; then
          session_state="alive"
        else
          session_state="idle"
        fi
        print "${i}. [${marker}] ${entry} (${session_state})"
      done
      ;;
    *)
      print "사용법:"
      print "  ducktape-taping bind"
      print "  ducktape-taping unbind"
      print "  ducktape-taping clear"
      print "  ducktape-taping --show"
      return 1
      ;;
  esac
}

ducktape-param() {
  local scope="${1:-show}"

  if [[ "$scope" == "show" ]]; then
    local gp lp merged
    gp=$(cat "$_DUCKTAPE_GLOBAL_PARAMS_DIR/.ducktape-params-${_DUCKTAPE_AGENT}" 2>/dev/null)
    lp=$(cat "$PWD/.ducktape-params" 2>/dev/null)
    local merged="$gp"
    [[ -n "$gp" && -n "$lp" ]] && merged="$gp $lp"
    [[ -z "$gp" && -n "$lp" ]] && merged="$lp"
    print "global: ${gp:-(없음)}"
    print "local:  ${lp:-(없음)}  [$PWD]"
    print "merged: ${merged:-(없음)}"
    return 0
  fi

  local file
  case "$scope" in
    global) file="$_DUCKTAPE_GLOBAL_PARAMS_DIR/.ducktape-params-${_DUCKTAPE_AGENT}" ;;
    local)  file="$PWD/.ducktape-params" ;;
    *)
      print "사용법:"
      print "  ducktape-param show"
      print "  ducktape-param global add <파라미터...>"
      print "  ducktape-param global set <파라미터...>"
      print "  ducktape-param global clear"
      print "  ducktape-param local  add <파라미터...>"
      print "  ducktape-param local  set <파라미터...>"
      print "  ducktape-param local  clear"
      return 1
      ;;
  esac

  local action="${2:-show}"
  shift 2 2>/dev/null

  case "$action" in
    add)
      local current
      current=$(cat "$file" 2>/dev/null)
      if [[ -n "$current" ]]; then
        echo "$current $*" > "$file"
      else
        echo "$*" > "$file"
      fi
      print "✓ $scope 파라미터 추가: $*"
      ;;
    set)
      echo "$*" > "$file"
      print "✓ $scope 파라미터 설정: $*"
      ;;
    clear)
      rm -f "$file"
      print "✓ $scope 파라미터 초기화"
      ;;
    show)
      local val
      val=$(cat "$file" 2>/dev/null)
      print "$scope: ${val:-(없음)}"
      ;;
    *)
      print "✗ 알 수 없는 액션: $action (add / set / clear / show)"
      return 1
      ;;
  esac
}

ducktape-uninstall() {
  print "              _         _   _"
  print "    __     __| |_  _ __| |_| |_ __ _ _ __  ___"
  print " __( o)>  / _\` | || / _| / /  _/ _\` | '_ \/ -_)"
  print " \ <_. )  \__,_|\_,_\__|_\_\\\__\__,_| .__/\___|"
  print "  \`---'                              |_|"
  print ""
  print "ducktape를 제거합니다..."

  local sessions
  sessions=$(tmux ls 2>/dev/null | grep "^ducktape-" | awk -F: '{print $1}')
  if [[ -n "$sessions" ]]; then
    echo "$sessions" | xargs -I{} tmux kill-session -t {} 2>/dev/null
    print "✓ tmux 세션 종료"
  fi

  rm -f "$HOME/.zsh/shell-agents-tmux.zsh"
  rm -f "$_DUCKTAPE_CONF"
  rm -f "$_DUCKTAPE_BIND_FILE"
  rm -f "$_DUCKTAPE_GLOBAL_PARAMS_DIR"/.ducktape-params-*
  rm -f "$_DUCKTAPE_LEGACY_TAPING_FILE"
  print "✓ 스크립트 제거"

  if [[ -f "$HOME/.zshrc" ]]; then
    sed -i '' '/# ducktape/d' "$HOME/.zshrc"
    sed -i '' '/shell-agents-tmux/d' "$HOME/.zshrc"
    print "✓ .zshrc 정리"
  fi

  if [[ -f "$HOME/.tmux.conf" ]]; then
    sed -i '' '/^# ducktape$/,/^# \/ducktape$/d' "$HOME/.tmux.conf"
    sed -i '' '/bind-key -n F2 /d' "$HOME/.tmux.conf"
    sed -i '' '/bind-key -n F12 run-shell/d' "$HOME/.tmux.conf"
    sed -i '' '/grep ducktape/d' "$HOME/.tmux.conf"
    tmux source-file "$HOME/.tmux.conf" 2>/dev/null || true
    print "✓ tmux.conf 정리"
  fi

  print ""
  print "✓ ducktape 제거 완료. 새 터미널을 여세요."
}

ducktape-status() {
  local session=$(_ducktape_session_for_dir "$PWD")
  local gp lp
  gp=$(cat "$_DUCKTAPE_GLOBAL_PARAMS_DIR/.ducktape-params-${_DUCKTAPE_AGENT}" 2>/dev/null)
  lp=$(cat "$PWD/.ducktape-params" 2>/dev/null)
  print "에이전트: $_DUCKTAPE_AGENT"
  print "  global params: ${gp:-(없음)}"
  print "  local  params: ${lp:-(없음)}"
  if _ducktape_bound_path_exists "$PWD"; then
    print "  binding: 등록됨"
  else
    print "  binding: 없음"
  fi
  if tmux has-session -t "$session" 2>/dev/null; then
    print "● 세션 실행 중 ($session)"
  else
    print "○ 세션 없음 ($PWD)"
  fi
}

ducktape-kill() {
  local action="${1:-current}"

  case "$action" in
    --bind-all|bind-all)
      _ducktape_prune_bound_paths >/dev/null

      local paths=()
      local entry
      while IFS= read -r entry; do
        [[ -n "$entry" ]] && paths+=("$entry")
      done < <(_ducktape_bound_paths)

      if (( ${#paths[@]} == 0 )); then
        print "✗ 바인드된 디렉토리 없음"
        return 1
      fi

      local session killed=0 missing=0
      for entry in "${paths[@]}"; do
        session=$(_ducktape_session_for_dir "$entry")
        if tmux has-session -t "$session" 2>/dev/null; then
          tmux kill-session -t "$session"
          print "✓ 세션 종료 ($session)"
          killed=$((killed + 1))
        else
          missing=$((missing + 1))
        fi
      done

      print "총 ${killed}개 종료, ${missing}개 없음"
      ;;
    ""|current)
      local session=$(_ducktape_session_for_dir "$PWD")
      if tmux has-session -t "$session" 2>/dev/null; then
        tmux kill-session -t "$session"
        print "✓ 세션 종료 ($session)"
      else
        print "✗ 세션 없음"
      fi
      ;;
    *)
      print "사용법:"
      print "  ducktape-kill"
      print "  ducktape-kill --bind-all"
      return 1
      ;;
  esac
}

ducktape-ls() {
  print "── ducktape sessions ──"
  tmux ls 2>/dev/null | grep "^ducktape-" || print "(없음)"
}

precmd_ducktape_indicator() {
  local session=$(_ducktape_session_for_dir "$PWD")
  if tmux has-session -t "$session" 2>/dev/null; then
    DUCKTAPE_INDICATOR="%F{magenta}●${_DUCKTAPE_AGENT}%f"
  else
    DUCKTAPE_INDICATOR=""
  fi
}
precmd_functions+=(precmd_ducktape_indicator)

PROMPT='${DUCKTAPE_INDICATOR:+$DUCKTAPE_INDICATOR }'"$PROMPT"
