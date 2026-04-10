# ducktape

```
              _         _   _
    __     __| |_  _ __| |_| |_ __ _ _ __  ___
 __( o)>  / _` | || / _| / /  _/ _` | '_ \/ -_)
 \ <_. )  \__,_|\_,_\__|_\_\\__\__,_| .__/\___|
  `---'                              |_|
```

tmux-based AI agent session manager.
Toggle attach/detach with a single key (F2), with automatic per-directory session management.

## Install

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/terria1020/ducktape/main/install.sh)"
```

### Requirements

- zsh
- tmux
- At least one AI agent: `claude` / `gemini` / `codex` / `cursor`
- (recommended) `fzf` — for the session picker

## Usage

### Key Bindings

| Key | Context | Action |
|-----|---------|--------|
| `F2` | Shell prompt | Attach to agent session for current directory (creates one if none exists) |
| `F2` | Inside agent | Detach → return to shell |
| `F12` | Inside agent | Restart agent (fresh context, no resume) |
| `Ctrl-B a` | Anywhere in tmux | fzf picker for all ducktape sessions |

### Per-directory Sessions

Each directory gets its own independent session.

```
~/project-a $ F2   →  ducktape-claude-a1b2c3d4 (new)
~/project-a $ F2   →  detach
~/project-b $ F2   →  ducktape-claude-e5f6g7h8 (new, separate session)
~/project-a $ F2   →  ducktape-claude-a1b2c3d4 (re-attach existing)
```

### Commands

```zsh
ducktape-alias      # Switch agent interactively
ducktape-status     # Show session status for current directory
ducktape-ls         # List all ducktape sessions
ducktape-kill       # Kill session for current directory
ducktape-uninstall  # Remove everything
```

### Switching Agents

```zsh
ducktape-alias
# → Select from detected agents via fzf
# → Takes effect in new terminals
```

## Uninstall

```zsh
ducktape-uninstall
```

Or manually:

```bash
rm ~/.zsh/shell-agents-tmux.zsh ~/.zsh/.ducktape-agent
# Remove the shell-agents-tmux line from .zshrc
# Remove the # ducktape ~ # /ducktape block from .tmux.conf
```

## File Layout

```
~/.zsh/shell-agents-tmux.zsh   # Main script
~/.zsh/.ducktape-agent         # Selected agent name
~/.tmux.conf                   # F2 / F12 / Ctrl-B a bindings
```

## Scroll Behavior

ducktape enables mouse scrolling via tmux (`set -g mouse on`).

**How it works:**
- At the shell prompt: mouse wheel enters tmux copy mode, allowing scrollback through terminal history
- Inside an agent: mouse scroll events are passed through to the agent's own UI (e.g. Claude Code handles its own scrolling)

**Limitations:**

| Situation | Behavior |
|-----------|----------|
| Agent uses alternate screen buffer (e.g. Claude Code) | tmux scrollback does **not** capture conversation history — only the agent's internal scroll works |
| After agent exits | Conversation output is gone; tmux scrollback shows only what was on screen before the agent launched |
| `Ctrl-B [` copy mode | Can scroll terminal history, but requires `q` to exit — not seamless |
| Mouse event conflicts | If both tmux and the agent try to capture mouse events, behavior may vary by terminal emulator |

> The fundamental constraint is that TUI agents use the **alternate screen buffer**, which tmux does not include in its scrollback history. This is a tmux architecture limitation, not specific to ducktape.

## Prompt Indicator

When an active session exists for the current directory, it appears in your prompt:

```
●claude ~/project $
```

---

> Korean documentation: [README.korean.md](./README.korean.md)
