# Ducktape — 에이전트 내부 전환 방법 정리

> 문제: 에이전트(claude/gemini/codex 등)가 stdin을 점유하기 때문에
> ZLE 바인딩(`^Tc` 등)이 에이전트 내부에서 동작하지 않음.

---

## 현재 구조

- `~/.zsh/shell-agents-tmux.zsh`
- 세션 네이밍: `ducktape-<hash8>-<agent>`
- ZLE 위젯으로 Ctrl-T prefix 사용 (쉘 프롬프트에서만 동작)

---

## 방법 1. tmux.conf 레벨 고정 키바인딩

tmux prefix(기본 `Ctrl-B`) 레벨에서 동작하므로 에이전트 안에서도 작동.

```bash
# ~/.tmux.conf
bind-key M-c switch-client -t ducktape-XXXXXXXX-claude
bind-key M-g switch-client -t ducktape-XXXXXXXX-gemini
bind-key M-x switch-client -t ducktape-XXXXXXXX-codex
bind-key M-u switch-client -t ducktape-XXXXXXXX-cursor
```

**단점:** 세션 이름이 디렉토리 해시 기반이라 고정 값 사용 불가.
정적 세션 이름으로 변경하거나, 별칭 스크립트로 보완 필요.

---

## 방법 2. tmux window 기반으로 전환

세션을 분리하지 않고 **하나의 세션 내 window**로 에이전트 관리.
`Ctrl-B 1/2/3/4` 또는 `Ctrl-B <window이름>`으로 native 전환 가능.

```zsh
_agent_window_run() {
  local agent=$1
  local bin=$2
  local session="ducktape-$(_agent_dir_key | head -c 8)"

  if ! tmux has-session -t "$session" 2>/dev/null; then
    tmux new-session -d -s "$session" -c "$PWD"
  fi

  # 해당 에이전트 window가 없으면 생성
  if ! tmux list-windows -t "$session" -F "#{window_name}" | grep -q "^${agent}$"; then
    tmux new-window -t "$session" -n "$agent" -c "$PWD" "$bin"
  fi

  # 해당 window로 전환 후 attach
  tmux select-window -t "$session:$agent"
  tmux attach-session -t "$session"
}
```

**장점:** tmux native 전환(`Ctrl-B n/p`, 번호키) 그대로 사용 가능.
**단점:** 현재 세션/window 구조 리팩터 필요.

---

## 방법 3. tmux display-popup + fzf picker ★ 추천

`.tmux.conf` 한 줄 추가로 즉시 사용 가능. 에이전트 내부에서 완전히 동작.

```bash
# ~/.tmux.conf
bind-key a display-popup -E \
  "tmux ls | grep ducktape | cut -d: -f1 | fzf --prompt='agent> ' | xargs -I{} tmux switch-client -t {}"
```

`Ctrl-B a` → floating 팝업에 ducktape 세션 목록 fzf → 선택 시 전환.

**장점:** 구현 1줄, UX 최상, 에이전트 무관하게 동작.
**필요:** `fzf` 설치 (`brew install fzf`)

---

## 방법 4. 세션 생성 시 동적 tmux 바인딩 주입

에이전트 세션을 생성할 때 `tmux bind-key`를 동시에 실행해
현재 살아있는 세션들로 키바인딩을 자동 갱신.

```zsh
_agent_tmux_run() {
  local agent=$1
  local bin=$2
  local session=$(_agent_session_name $agent)

  if ! _agent_session_alive "$session"; then
    tmux new-session -d -s "$session" -c "$PWD" "$bin"

    # 세션 생성 시점에 tmux 레벨 키 동적 등록
    local -A key_map=(claude M-c gemini M-g codex M-x cursor M-u)
    for a k in ${(kv)key_map}; do
      local s=$(_agent_session_name $a)
      _agent_session_alive "$s" && \
        tmux bind-key "$k" switch-client -t "$s"
    done
  fi

  tmux attach-session -t "$session"
}
```

**장점:** 정적 설정 불필요, 현재 구조 그대로 유지 가능.
**단점:** 세션 종료 후 바인딩이 남아있을 수 있어 cleanup 필요.

---

## 방법 5. OSC 이스케이프 시퀀스 + 외부 데몬 (고급)

터미널 에뮬레이터(Wezterm, iTerm2)가 지원하는 경우,
에이전트 내부에서 특수 문자열을 출력해 외부 데몬이 세션 전환.

```bash
# 에이전트 내부에서 실행 (예: claude custom command)
printf '\033]1337;Custom=ducktape:switch:gemini\007'
```

데몬이 PTY 출력을 감시하다 파싱해서 `tmux switch-client` 실행.

**장점:** 에이전트 안에서 명령으로 전환 트리거 가능.
**단점:** 구현 복잡도 높음, 터미널 에뮬레이터 의존.

---

## 비교 요약

| 방법 | 구현 난이도 | UX | 에이전트 내 동작 | 비고 |
|------|:-----------:|:--:|:----------------:|------|
| 1. .tmux.conf 고정 키 | 낮음 | ★★☆ | ✅ | 해시 고정 문제 |
| 2. window 기반 리팩터 | 중간 | ★★★★ | ✅ | 구조 변경 필요 |
| 3. popup + fzf | **낮음** | ★★★★★ | ✅ | **즉시 적용 가능** |
| 4. 동적 bind-key 주입 | 중간 | ★★★ | ✅ | cleanup 주의 |
| 5. OSC 데몬 | 높음 | ★★☆ | ✅ | 터미널 의존 |

---

## 권장 순서

1. **지금 당장** → 방법 3 (popup + fzf) `.tmux.conf`에 한 줄 추가
2. **구조 개선** → 방법 2 (window 기반)으로 `_agent_tmux_run` 리팩터
3. **필요 시** → 방법 4 병행으로 고정 키(`Alt+c/g/x/u`) 제공

---

## 즉시 쓸 수 있는 탈출 방법 (지금 당장)

```
Ctrl-B d     → 현재 세션 detach (세션 살아있고 쉘로 복귀)
Ctrl-B s     → 세션 목록 → 방향키로 전환
Ctrl-B $     → 현재 세션 이름 변경
```
