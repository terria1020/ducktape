#!/bin/bash
# ducktape installer
# curl -fsSL https://raw.githubusercontent.com/terria1020/ducktape/main/install.sh | bash

set -euo pipefail

ZSH_DIR="$HOME/.zsh"
ZSH_SCRIPT="$ZSH_DIR/shell-agents-tmux.zsh"
AGENT_CONF="$ZSH_DIR/.ducktape-agent"
TMUX_CONF="$HOME/.tmux.conf"
ZSHRC="$HOME/.zshrc"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${BOLD}▶${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warn()    { echo -e "${YELLOW}!${NC} $*"; }
error()   { echo -e "${RED}✗${NC} $*" >&2; exit 1; }

strip_ducktape_tmux_block() {
  local file="$1"
  [[ -f "$file" ]] || return 0

  perl -0pi -e 's/\n?# ducktape\n.*?\n# \/ducktape\n/\n/s' "$file"
  perl -0pi -e 's/\nbind-key -n F12 run-shell '\''\\\n.*?\n\s*tmux rename-session -t "\$TMP" "\$S"'\''\n/\n/s' "$file"
  perl -0pi -e 's/\nbind-key a display-popup -E \\\n\s*".*?xargs -I\{\} tmux switch-client -t \{\}"\n/\n/s' "$file"
  perl -0pi -e 's/\nbind-key a run-shell \\\n\s*'\''if command -v fzf .*?\n\s*fi'\''\n/\n/s' "$file"
  sed -i '' '/bind-key -n F2 /d' "$file"
  sed -i '' '/bind-key -n F10 run-shell/d' "$file"
  sed -i '' '/bind-key -n F12 run-shell/d' "$file"
  sed -i '' '/bind-key a display-popup/d' "$file"
  sed -i '' '/bind-key a run-shell/d' "$file"
  sed -i '' '/copy-pipe-and-cancel "pbcopy"/d' "$file"
  sed -i '' '/clear-selection/d' "$file"
}

echo ""
echo -e "${BOLD}              _         _   _${NC}"
echo -e "${BOLD}    __     __| |_  _ __| |_| |_ __ _ _ __  ___${NC}"
echo -e "${BOLD} __( o)>  / _\` | || / _| / /  _/ _\` | '_ \/ -_)${NC}"
echo -e "${BOLD} \ <_. )  \__,_|\_,_\__|_\_\\\__\__,_| .__/\___|${NC}"
echo -e "${BOLD}  \`---'                              |_|${NC}"
echo ""

# ── 의존성 확인 ───────────────────────────

info "의존성 확인 중..."

command -v zsh  &>/dev/null || error "zsh가 필요합니다"

HAS_TMUX=1
if ! command -v tmux &>/dev/null; then
  HAS_TMUX=0
  warn "tmux 없음 — F2/F10 세션 기능은 비활성화됩니다 (brew install tmux)"
fi

if ! command -v fzf &>/dev/null; then
  warn "fzf 없음 — Ctrl-B a 피커 기능 제한됩니다 (brew install fzf)"
fi

# ── 에이전트 감지 ─────────────────────────

info "설치된 에이전트 감지 중..."

AGENTS=()
command -v claude &>/dev/null && AGENTS+=(claude)
command -v gemini &>/dev/null && AGENTS+=(gemini)
command -v codex  &>/dev/null && AGENTS+=(codex)
command -v cursor &>/dev/null && AGENTS+=(cursor)

if [[ ${#AGENTS[@]} -eq 0 ]]; then
  error "감지된 에이전트 없음. claude / gemini / codex 중 하나를 설치하세요."
fi

echo "  감지됨: ${AGENTS[*]}"

# ── 에이전트 선택 ─────────────────────────

if [[ ${#AGENTS[@]} -eq 1 ]]; then
  SELECTED="${AGENTS[0]}"
  info "에이전트 자동 선택: $SELECTED"
elif command -v fzf &>/dev/null; then
  echo ""
  SELECTED=$(printf '%s\n' "${AGENTS[@]}" | fzf --prompt="사용할 에이전트 선택> " --height=10)
else
  echo ""
  echo "사용할 에이전트를 선택하세요:"
  select a in "${AGENTS[@]}"; do [[ -n "$a" ]] && SELECTED="$a" && break; done
fi

[[ -z "${SELECTED:-}" ]] && error "에이전트 선택 취소됨"
info "선택: $SELECTED"

# ── 파일 설치 ─────────────────────────────

mkdir -p "$ZSH_DIR"

info "shell-agents-tmux.zsh 다운로드 중..."
curl -fsSL "https://raw.githubusercontent.com/terria1020/ducktape/main/shell-agents-tmux.zsh" -o "$ZSH_SCRIPT"
success "스크립트 설치: $ZSH_SCRIPT"

echo "$SELECTED" > "$AGENT_CONF"
success "에이전트 설정: $SELECTED → $AGENT_CONF"

# ── .zshrc 설정 ───────────────────────────

ZSHRC_LINE="source \"$ZSH_SCRIPT\" # ducktape"
if grep -q "shell-agents-tmux" "$ZSHRC" 2>/dev/null; then
  warn ".zshrc 이미 설정됨 (건너뜀)"
else
  echo "" >> "$ZSHRC"
  echo "$ZSHRC_LINE" >> "$ZSHRC"
  success ".zshrc 업데이트"
fi

# ── tmux.conf 설정 ────────────────────────

if [[ "$HAS_TMUX" -eq 1 ]]; then
  touch "$TMUX_CONF"
  strip_ducktape_tmux_block "$TMUX_CONF"

  cat >> "$TMUX_CONF" << 'EOF'

# ducktape
set -g mouse on
set -g history-limit 100000
bind-key -n F2 run-shell 'zsh -lc "source \"$HOME/.zsh/shell-agents-tmux.zsh\"; ducktape-tmux-f2"'
bind-key -n F10 run-shell 'zsh -lc "source \"$HOME/.zsh/shell-agents-tmux.zsh\"; ducktape-tmux-f12"'
bind-key a run-shell \
  'if command -v fzf >/dev/null 2>&1; then \
     tmux display-popup -E "tmux ls 2>/dev/null | grep ducktape | cut -d: -f1 | fzf --prompt=\"agent> \" --height=10 | xargs -I{} tmux switch-client -t {}"; \
   else \
     tmux choose-session; \
   fi'
bind -T copy-mode MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "pbcopy"
bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "pbcopy"
bind -T copy-mode MouseDown1Pane send-keys -X clear-selection
bind -T copy-mode-vi MouseDown1Pane send-keys -X clear-selection
# /ducktape
EOF

  success "tmux.conf 업데이트"

  tmux source-file "$TMUX_CONF" 2>/dev/null && success "tmux 설정 적용" || true
else
  warn "tmux.conf 설정 건너뜀 — ducktape-call은 사용 가능합니다"
fi

# ── 완료 ──────────────────────────────────

echo ""
echo -e "${GREEN}────────────────────────────────────${NC}"
echo -e "${BOLD}설치 완료!${NC} 에이전트: ${BOLD}$SELECTED${NC}"
echo ""
if [[ "$HAS_TMUX" -eq 1 ]]; then
  echo "  F2            → $SELECTED attach/detach 토글"
  echo "  F10           → 일반 터미널: 1번 bound 세션 진입 / tmux 안: bound 세션 순환"
  echo "  Ctrl-B a      → 세션 목록 fzf 피커"
else
  echo "  tmux 없음     → F2/F10 세션 기능 비활성화"
fi
echo ""
echo "  ducktape-alias     → 에이전트 변경"
echo "  ducktape-call      → tmux 없이 지정 에이전트를 병합 파라미터로 실행"
echo "  ducktape-taping    → 번호 기반 bind/unbind/clear/show"
echo "  ducktape-jumping   → 번호로 bound 세션 attach/switch"
echo "  ducktape-param     → 실행 파라미터 관리 (글로벌/로컬)"
echo "  ducktape-status    → 현재 세션 상태"
echo "  ducktape-ls        → 전체 세션 목록"
echo "  ducktape-kill      → 현재 디렉토리 세션 종료 / --bind-all / --help"
echo "  ducktape-uninstall → 완전 제거"
echo "  각 커맨드 --help   → 사용법 확인"
echo ""
echo -e "적용: ${BOLD}source ~/.zshrc${NC} (또는 새 터미널)"
echo ""
