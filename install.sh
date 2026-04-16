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

echo ""
echo -e "${BOLD}              _         _   _${NC}"
echo -e "${BOLD}    __     __| |_  _ __| |_| |_ __ _ _ __  ___${NC}"
echo -e "${BOLD} __( o)>  / _\` | || / _| / /  _/ _\` | '_ \/ -_)${NC}"
echo -e "${BOLD} \ <_. )  \__,_|\_,_\__|_\_\\\__\__,_| .__/\___|${NC}"
echo -e "${BOLD}  \`---'                              |_|${NC}"
echo ""

# ── 의존성 확인 ───────────────────────────

info "의존성 확인 중..."

command -v tmux &>/dev/null || error "tmux가 필요합니다: brew install tmux"
command -v zsh  &>/dev/null || error "zsh가 필요합니다"

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

if grep -q "ducktape" "$TMUX_CONF" 2>/dev/null; then
  warn "tmux.conf 이미 설정됨 (건너뜀)"
else
  cat >> "$TMUX_CONF" << 'EOF'

# ducktape
set -g mouse on
set -g history-limit 100000
bind-key -n F2 run-shell 'zsh -lc "source \"$HOME/.zsh/shell-agents-tmux.zsh\"; ducktape-tmux-f2"'
bind-key -n F10 run-shell 'zsh -lc "source \"$HOME/.zsh/shell-agents-tmux.zsh\"; ducktape-tmux-f12"'
bind-key a display-popup -E \
  "tmux ls 2>/dev/null | grep ducktape | cut -d: -f1 | fzf --prompt='agent> ' --height=10 | xargs -I{} tmux switch-client -t {}"
bind -T copy-mode MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "pbcopy"
bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "pbcopy"
bind -T copy-mode MouseDown1Pane send-keys -X clear-selection
bind -T copy-mode-vi MouseDown1Pane send-keys -X clear-selection
# /ducktape
EOF
  success "tmux.conf 업데이트"
fi

tmux source-file "$TMUX_CONF" 2>/dev/null && success "tmux 설정 적용" || true

# ── 완료 ──────────────────────────────────

echo ""
echo -e "${GREEN}────────────────────────────────────${NC}"
echo -e "${BOLD}설치 완료!${NC} 에이전트: ${BOLD}$SELECTED${NC}"
echo ""
echo "  F2            → $SELECTED attach/detach 토글"
echo "  F10           → bind된 디렉토리 세션 순환"
echo "  Ctrl-B a      → 세션 목록 fzf 피커"
echo ""
echo "  ducktape-alias     → 에이전트 변경"
echo "  ducktape-taping    → bind/unbind/clear/show"
echo "  ducktape-param     → 실행 파라미터 관리 (글로벌/로컬)"
echo "  ducktape-status    → 현재 세션 상태"
echo "  ducktape-ls        → 전체 세션 목록"
echo "  ducktape-kill      → 현재 디렉토리 세션 종료"
echo "  ducktape-uninstall → 완전 제거"
echo ""
echo -e "적용: ${BOLD}source ~/.zshrc${NC} (또는 새 터미널)"
echo ""
