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
옵션 `taping` 바인딩으로 F12에서 저장된 디렉토리별 에이전트 세션을 순환할 수 있습니다.

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
| `F12` | 에이전트 안 | bind된 다음 디렉토리 세션으로 순환 |
| `Ctrl-B a` | tmux 안 어디서든 | 전체 ducktape 세션 fzf 피커 |

### 디렉토리별 세션

디렉토리마다 독립적인 세션이 생성됩니다.

```
~/project-a $ F2   →  ducktape-claude-a1b2c3d4 (신규)
~/project-a $ F2   →  detach
~/project-b $ F2   →  ducktape-claude-e5f6g7h8 (신규, 별도 세션)
~/project-a $ F2   →  ducktape-claude-a1b2c3d4 (기존 세션 재attach)
```

세션 bind 사용 시:

```
~/project-a $ ducktape-taping bind
~/project-b $ ducktape-taping bind
~/project-a $ F2   →  ducktape-claude-a1b2c3d4
~/project-a $ F12  →  ducktape-claude-e5f6g7h8
~/project-b $ F12  →  ducktape-claude-a1b2c3d4
```

### 커맨드

```zsh
ducktape-alias      # 에이전트 변경 (인터랙티브 선택)
ducktape-taping     # F12 순환용 디렉토리 bind 관리
ducktape-param      # 실행 파라미터 관리 (글로벌/로컬)
ducktape-status     # 현재 디렉토리 세션 상태 확인
ducktape-ls         # 전체 ducktape 세션 목록
ducktape-kill       # 현재 디렉토리 세션 종료
ducktape-kill --bind-all  # 바인드된 디렉토리 세션 전체 종료
ducktape-uninstall  # 완전 제거
```

### 에이전트 변경

```zsh
ducktape-alias
# → 설치된 에이전트 목록에서 fzf로 선택
# → 새 터미널부터 적용
```

### Taping 바인딩

`ducktape-taping`은 디렉토리 목록을 원형 리스트처럼 관리합니다.
F12는 저장된 순서대로 다음 디렉토리의 에이전트 세션으로 이동합니다.
같은 경로는 한 번만 저장되며, 사라진 디렉토리는 자동 정리됩니다.

```zsh
ducktape-taping bind
ducktape-taping unbind
ducktape-taping clear
ducktape-taping --show
```

동작:
- `bind`: 현재 디렉토리를 순환 목록에 추가, 이미 있으면 순서 유지
- `unbind`: 현재 디렉토리를 목록에서 제거
- `clear`: 전체 목록 삭제
- `--show`: 저장된 순서 출력, 현재 디렉토리 표시

대상 디렉토리의 에이전트 세션이 꺼져 있으면 F12가 자동으로 다시 띄웁니다.

### 실행 파라미터 관리

에이전트 실행 시 자동으로 붙일 플래그를 미리 설정합니다.  
파라미터는 두 가지 범위로 관리되며, 실행 시 병합됩니다:

| 범위 | 파일 | 적용 시점 |
|------|------|-----------|
| **global** | `~/.zsh/.ducktape-params` | 모든 세션에 항상 적용 |
| **local** | `$PWD/.ducktape-params` | 해당 디렉토리에서 시작한 세션에만 적용 |

```zsh
# 글로벌 — 어디서든 yolo 모드로 실행
ducktape-param global add --dangerously-skip-permissions

# 로컬 — 이 프로젝트에서만 특정 모델 사용
ducktape-param local add --model claude-opus-4-5

# 병합 결과 확인
ducktape-param show
# global: --dangerously-skip-permissions
# local:  --model claude-opus-4-5  [~/my-project]
# merged: --dangerously-skip-permissions --model claude-opus-4-5

# 글로벌 파라미터 전체 교체
ducktape-param global set --dangerously-skip-permissions --verbose

# 초기화
ducktape-param global clear
ducktape-param local clear
```

로컬 `.ducktape-params` 파일은 프로젝트 저장소에 커밋하거나 `.gitignore`에 추가해 관리할 수 있습니다.

> **기존 설치 사용자 주의:** `~/.tmux.conf`의 F12 바인딩은 설치 시 한 번 기록되며 자동 업데이트되지 않습니다. 새 순환 동작을 쓰려면 재설치가 필요합니다.

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
~/.zsh/.ducktape-bindings      # F12 순환용 디렉토리 목록 (선택)
~/.zsh/.ducktape-params        # 글로벌 실행 파라미터 (선택)
$PWD/.ducktape-params          # 프로젝트별 로컬 파라미터 (선택)
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
