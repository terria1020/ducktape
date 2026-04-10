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

## 프롬프트 인디케이터

현재 디렉토리에 활성 세션이 있으면 프롬프트 앞에 표시:

```
●claude ~/project $
```
