# ducktape

```
              _         _   _
    __     __| |_  _ __| |_| |_ __ _ _ __  ___
 __( o)>  / _` | || / _| / /  _/ _` | '_ \/ -_)
 \ <_. )  \__,_|\_,_\__|_\_\\__\__,_| .__/\___|
  `---'                              |_|
```

tmux 기반 AI 에이전트 세션 매니저.
F2 하나로 attach/detach 토글, 디렉토리별 세션 자동 관리.

## 설치

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/terria1020/ducktape/main/install.sh)"
```

### 필요 조건

- zsh
- tmux
- AI 에이전트 1개 이상: `claude` / `gemini` / `codex` / `cursor`
- (권장) `fzf` — 세션 피커 사용 시

## 사용법

### 키 바인딩

| 키 | 상황 | 동작 |
|----|------|------|
| `F2` | 쉘 프롬프트 | 현재 디렉토리 에이전트 세션 attach (없으면 신규 생성) |
| `F2` | 에이전트 안 | detach → 쉘 복귀 |
| `F12` | 에이전트 안 | 에이전트 재시작 (컨텍스트 초기화, resume 없음) |
| `Ctrl-B a` | tmux 안 어디서든 | 전체 ducktape 세션 fzf 피커 |

### 디렉토리별 세션

디렉토리마다 독립적인 세션이 생성됩니다.

```
~/project-a $ F2   →  ducktape-claude-a1b2c3d4 (신규)
~/project-a $ F2   →  detach
~/project-b $ F2   →  ducktape-claude-e5f6g7h8 (신규, 별도 세션)
~/project-a $ F2   →  ducktape-claude-a1b2c3d4 (기존 세션 재attach)
```

### 커맨드

```zsh
ducktape-alias      # 에이전트 변경 (인터랙티브 선택)
ducktape-status     # 현재 디렉토리 세션 상태 확인
ducktape-ls         # 전체 ducktape 세션 목록
ducktape-kill       # 현재 디렉토리 세션 종료
ducktape-uninstall  # 완전 제거
```

### 에이전트 변경

```zsh
ducktape-alias
# → 설치된 에이전트 목록에서 fzf로 선택
# → 새 터미널부터 적용
```

## 제거

```zsh
ducktape-uninstall
```

또는 수동 제거:

```bash
rm ~/.zsh/shell-agents-tmux.zsh ~/.zsh/.ducktape-agent
# .zshrc에서 shell-agents-tmux 라인 삭제
# .tmux.conf에서 # ducktape ~ # /ducktape 블록 삭제
```

## 파일 구성

```
~/.zsh/shell-agents-tmux.zsh   # 메인 스크립트
~/.zsh/.ducktape-agent         # 선택된 에이전트 저장
~/.tmux.conf                   # F2/F12/Ctrl-B a 바인딩
```

## 스크롤 동작

ducktape는 tmux의 마우스 지원(`set -g mouse on`)을 통해 휠 스크롤을 활성화합니다.

**동작 방식:**
- 쉘 프롬프트에서: 마우스 휠이 tmux copy mode를 진입시켜 터미널 히스토리 스크롤 가능
- 에이전트 안에서: 마우스 스크롤 이벤트가 에이전트 UI로 패스스루 (예: Claude Code가 자체적으로 스크롤 처리)

**제한 사항:**

| 상황 | 동작 |
|------|------|
| 에이전트가 alternate screen buffer 사용 시 (예: Claude Code) | tmux 스크롤백에 대화 내용이 **기록되지 않음** — 에이전트 자체 스크롤만 동작 |
| 에이전트 종료 후 | 대화 출력이 사라지며, 에이전트 실행 전 화면만 스크롤백에 남음 |
| `Ctrl-B [` copy mode | 터미널 히스토리 스크롤 가능하나 `q`로 나와야 해서 불편 |
| 마우스 이벤트 충돌 | tmux와 에이전트가 동시에 마우스를 캡처하려 할 때 터미널 에뮬레이터에 따라 동작이 달라질 수 있음 |

> 핵심 제약: TUI 에이전트는 **alternate screen buffer**를 사용하며, tmux는 이를 스크롤백 히스토리에 포함하지 않습니다. 이는 ducktape의 문제가 아닌 tmux 아키텍처의 구조적 한계입니다.

## 프롬프트 인디케이터

현재 디렉토리에 활성 세션이 있으면 프롬프트 앞에 표시:

```
●claude ~/project $
```
