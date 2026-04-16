#######################
# ~/.zsh/shell-agents-tmux.zsh
# ducktape — F2 토글 (디렉토리별 세션)
# F2: 쉘 → attach/신규, tmux 안 → detach (tmux.conf 담당)

setopt PROMPT_SUBST

# ─────────────────────────────────────────
# tmux 의존성 guard — 없으면 조용히 비활성화
# ─────────────────────────────────────────

if ! command -v tmux &>/dev/null; then
  print "⚠️  ducktape: tmux을 찾을 수 없습니다. 설치 후 다시 시도하세요." >&2
  print "   brew install tmux" >&2
  return 0
fi

_DUCKTAPE_CONF="$HOME/.zsh/.ducktape-agent"
_DUCKTAPE_AGENT=$(cat "$_DUCKTAPE_CONF" 2>/dev/null || echo "claude")
_DUCKTAPE_GLOBAL_PARAMS_DIR="$HOME/.zsh"
_DUCKTAPE_TAPING_FILE="$PWD/.ducktape-taping"

# 표기명 → 실제 실행 커맨드 매핑 (글로벌 + 로컬 파라미터 포함)
_ducktape_cmd() {
  local agent
  case "$_DUCKTAPE_AGENT" in
    cursor) agent="agent" ;;
    *)      agent="$_DUCKTAPE_AGENT" ;;
  esac

  local gp lp
  gp=$(cat "$_DUCKTAPE_GLOBAL_PARAMS_DIR/.ducktape-params-${_DUCKTAPE_AGENT}" 2>/dev/null)
  lp=$(cat "$PWD/.ducktape-params" 2>/dev/null)

  local cmd="$agent"
  [[ -n "$gp" ]] && cmd="$cmd $gp"
  [[ -n "$lp" ]] && cmd="$cmd $lp"
  print "$cmd"
}

# ─────────────────────────────────────────
# 세션 이름: ducktape-<agent>-<hash8>
# ─────────────────────────────────────────

_ducktape_session() {
  local hash=$(print -n "$PWD" | shasum | awk '{print $1}')
  print "ducktape-${_DUCKTAPE_AGENT}-${hash:0:8}"
}

_ducktape_tap_session() {
  local hash=$(print -n "$PWD" | shasum | awk '{print $1}')
  print "ducktape-tap-${hash:0:8}"
}

_ducktape_taping_enabled() {
  [[ -f "$_DUCKTAPE_TAPING_FILE" ]] && grep -q '^enabled$' "$_DUCKTAPE_TAPING_FILE" 2>/dev/null
}

_ducktape_attach_or_create() {
  local session="$1"
  local mode="$2"

  if tmux has-session -t "$session" 2>/dev/null; then
    BUFFER="tmux attach-session -t '$session'"
  else
    if [[ "$mode" == "tap" ]]; then
      BUFFER="tmux new-session -d -s '$session' -c '$PWD' && tmux attach-session -t '$session'"
    else
      BUFFER="tmux new-session -d -s '$session' -c '$PWD' $(_ducktape_cmd) && tmux attach-session -t '$session'"
    fi
  fi
}

# ─────────────────────────────────────────
# F2 ZLE 위젯
# ─────────────────────────────────────────

_ducktape_f2_widget() {
  if _ducktape_taping_enabled; then
    _ducktape_attach_or_create "$(_ducktape_tap_session)" "tap"
  else
    _ducktape_attach_or_create "$(_ducktape_session)" "agent"
  fi
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

# ─────────────────────────────────────────
# ducktape-alias — 에이전트 변경
# ─────────────────────────────────────────

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
      selected=$agent; break
    done
  fi

  [[ -z "$selected" ]] && print "취소됨" && return 0

  print "$selected" > "$_DUCKTAPE_CONF"
  _DUCKTAPE_AGENT="$selected"
  print "✓ 에이전트 변경: $selected"
  print "  새 터미널 또는 'source ~/.zsh/shell-agents-tmux.zsh' 후 적용"
}

# ─────────────────────────────────────────
# ducktape-taping — 순정 터미널 세션 관리
# ─────────────────────────────────────────

ducktape-taping() {
  local action="${1:-show}"
  local file="$_DUCKTAPE_TAPING_FILE"

  case "$action" in
    enable)
      print "enabled" > "$file"
      print "✓ taping 활성화"
      print "  F2 → 순정 터미널 세션으로 attach"
      ;;
    disable)
      rm -f "$file"
      print "✓ taping 비활성화"
      print "  F2 → ducktape-alias 기반 에이전트 세션으로 attach"
      ;;
    show)
      if _ducktape_taping_enabled; then
        print "taping: enabled"
        print "session: $(_ducktape_tap_session)"
      else
        print "taping: disabled"
      fi
      ;;
    *)
      print "사용법:"
      print "  ducktape-taping --enable"
      print "  ducktape-taping --disable"
      print "  ducktape-taping --show"
      return 1
      ;;
  esac
}

# ─────────────────────────────────────────
# ducktape-param — 실행 파라미터 관리
# ─────────────────────────────────────────

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

# ─────────────────────────────────────────
# ducktape-uninstall — 완전 제거
# ─────────────────────────────────────────

ducktape-uninstall() {
  print "              _         _   _"
  print "    __     __| |_  _ __| |_| |_ __ _ _ __  ___"
  print " __( o)>  / _\` | || / _| / /  _/ _\` | '_ \/ -_)"
  print " \ <_. )  \__,_|\_,_\__|_\_\\\__\__,_| .__/\___|"
  print "  \`---'                              |_|"
  print ""
  print "ducktape를 제거합니다..."

  # 1. 모든 ducktape 세션 종료
  local sessions
  sessions=$(tmux ls 2>/dev/null | grep "^ducktape-" | awk -F: '{print $1}')
  if [[ -n "$sessions" ]]; then
    echo "$sessions" | xargs -I{} tmux kill-session -t {} 2>/dev/null
    print "✓ tmux 세션 종료"
  fi

  # 2. 스크립트 파일 제거
  rm -f "$HOME/.zsh/shell-agents-tmux.zsh"
  rm -f "$_DUCKTAPE_CONF"
  rm -f "$_DUCKTAPE_GLOBAL_PARAMS_DIR"/.ducktape-params-*
  rm -f "$_DUCKTAPE_TAPING_FILE"
  print "✓ 스크립트 제거"

  # 3. .zshrc에서 ducktape 라인 제거
  if [[ -f "$HOME/.zshrc" ]]; then
    sed -i '' '/# ducktape/d' "$HOME/.zshrc"
    sed -i '' '/shell-agents-tmux/d' "$HOME/.zshrc"
    print "✓ .zshrc 정리"
  fi

  # 4. tmux.conf에서 ducktape 블록 제거
  if [[ -f "$HOME/.tmux.conf" ]]; then
    # ducktape 마커 사이 블록 삭제
    sed -i '' '/^# ducktape$/,/^# \/ducktape$/d' "$HOME/.tmux.conf"
    # 개별 바인딩 라인 제거 (마커 없이 추가된 경우)
    sed -i '' '/bind-key -n F2 detach-client/d' "$HOME/.tmux.conf"
    sed -i '' '/bind-key -n F12 run-shell/d' "$HOME/.tmux.conf"
    sed -i '' '/tmp_restart/d' "$HOME/.tmux.conf"
    sed -i '' '/pane_current_path/d' "$HOME/.tmux.conf"
    sed -i '' '/session_name/d' "$HOME/.tmux.conf"
    sed -i '' '/grep ducktape/d' "$HOME/.tmux.conf"
    sed -i '' "/bind-key a display-popup.*ducktape/d" "$HOME/.tmux.conf"
    tmux source-file "$HOME/.tmux.conf" 2>/dev/null || true
    print "✓ tmux.conf 정리"
  fi

  print ""
  print "✓ ducktape 제거 완료. 새 터미널을 여세요."
}

# ─────────────────────────────────────────
# 유틸리티
# ─────────────────────────────────────────

ducktape-status() {
  local session
  local gp lp
  gp=$(cat "$_DUCKTAPE_GLOBAL_PARAMS_DIR/.ducktape-params-${_DUCKTAPE_AGENT}" 2>/dev/null)
  lp=$(cat "$PWD/.ducktape-params" 2>/dev/null)
  print "에이전트: $_DUCKTAPE_AGENT"
  print "  global params: ${gp:-(없음)}"
  print "  local  params: ${lp:-(없음)}"
  if _ducktape_taping_enabled; then
    session=$(_ducktape_tap_session)
    print "  taping: enabled"
  else
    session=$(_ducktape_session)
    print "  taping: disabled"
  fi
  if tmux has-session -t "$session" 2>/dev/null; then
    print "● 세션 실행 중 ($session)"
  else
    print "○ 세션 없음 ($PWD)"
  fi
}

ducktape-kill() {
  local session
  if _ducktape_taping_enabled; then
    session=$(_ducktape_tap_session)
  else
    session=$(_ducktape_session)
  fi
  if tmux has-session -t "$session" 2>/dev/null; then
    tmux kill-session -t "$session"
    print "✓ 세션 종료 ($session)"
  else
    print "✗ 세션 없음"
  fi
}

ducktape-ls() {
  print "── ducktape sessions ──"
  tmux ls 2>/dev/null | grep "^ducktape-" || print "(없음)"
}

# ─────────────────────────────────────────
# 프롬프트 인디케이터
# ─────────────────────────────────────────

precmd_ducktape_indicator() {
  local session label
  if _ducktape_taping_enabled; then
    session=$(_ducktape_tap_session)
    label="tap"
  else
    session=$(_ducktape_session)
    label="$_DUCKTAPE_AGENT"
  fi
  if tmux has-session -t "$session" 2>/dev/null; then
    DUCKTAPE_INDICATOR="%F{magenta}●${label}%f"
  else
    DUCKTAPE_INDICATOR=""
  fi
}
precmd_functions+=(precmd_ducktape_indicator)

PROMPT='${DUCKTAPE_INDICATOR:+$DUCKTAPE_INDICATOR }'"$PROMPT"
