#!/bin/bash
# ducktape uninstaller
# curl -fsSL https://raw.githubusercontent.com/terria1020/ducktape/main/uninstall.sh | bash

set -euo pipefail

ZSH_DIR="$HOME/.zsh"
ZSH_SCRIPT="$ZSH_DIR/shell-agents-tmux.zsh"
AGENT_CONF="$ZSH_DIR/.ducktape-agent"
BIND_FILE="$ZSH_DIR/.ducktape-bindings"
TAPING_FILE="$PWD/.ducktape-taping"
TMUX_CONF="$HOME/.tmux.conf"
ZSHRC="$HOME/.zshrc"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'
info() { echo -e "${BOLD}▶${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }

strip_ducktape_tmux_block() {
  local file="$1"
  [[ -f "$file" ]] || return 0

  perl -0pi -e 's/\n?# ducktape\n.*?\n# \/ducktape\n/\n/s' "$file"
  sed -i '' '/bind-key -n F2 /d' "$file"
  sed -i '' '/bind-key -n F12 run-shell/d' "$file"
  sed -i '' '/bind-key a display-popup/d' "$file"
  sed -i '' '/set -g mouse on/d' "$file"
  sed -i '' '/set -g history-limit 100000/d' "$file"
  sed -i '' '/copy-pipe-and-cancel "pbcopy"/d' "$file"
  sed -i '' '/clear-selection/d' "$file"
}

info "ducktape를 제거합니다..."

if command -v tmux >/dev/null 2>&1; then
  sessions=$(tmux ls 2>/dev/null | grep "^ducktape-" | awk -F: '{print $1}' || true)
  if [[ -n "${sessions:-}" ]]; then
    echo "$sessions" | xargs -I{} tmux kill-session -t {} 2>/dev/null || true
    success "tmux 세션 종료"
  else
    info "종료할 ducktape tmux 세션 없음"
  fi
else
  warn "tmux를 찾을 수 없어 세션 종료는 건너뜁니다"
fi

rm -f "$ZSH_SCRIPT"
rm -f "$AGENT_CONF"
rm -f "$BIND_FILE"
rm -f "$ZSH_DIR"/.ducktape-params-*
rm -f "$TAPING_FILE"
success "설정 파일 제거"

if [[ -f "$ZSHRC" ]]; then
  sed -i '' '/# ducktape/d' "$ZSHRC"
  sed -i '' '/shell-agents-tmux/d' "$ZSHRC"
  success ".zshrc 정리"
fi

if [[ -f "$TMUX_CONF" ]]; then
  strip_ducktape_tmux_block "$TMUX_CONF"
  if command -v tmux >/dev/null 2>&1; then
    tmux source-file "$TMUX_CONF" 2>/dev/null || true
  fi
  success "tmux.conf 정리"
fi

echo ""
echo -e "${GREEN}────────────────────────────────────${NC}"
echo -e "${BOLD}제거 완료!${NC}"
echo ""
echo "새 터미널을 열거나 쉘을 다시 시작하세요."
