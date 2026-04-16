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
Optional `taping` mode turns F2 into an agent/tap/shell cycle for the current directory.

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
| `F2` | Shell prompt + taping enabled | Attach to agent session for current directory |
| `F2` | Inside agent | Switch to tap session for current directory |
| `F2` | Inside tap session | Detach → return to shell |
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

With taping enabled:

```
~/project-a $ ducktape-taping --enable
~/project-a $ F2   →  ducktape-claude-a1b2c3d4
~/project-a $ F2   →  ducktape-tap-a1b2c3d4 (new or existing)
~/project-a $ F2   →  detach
~/project-a $ ducktape-taping --disable
~/project-a $ F2   →  ducktape-claude-a1b2c3d4
```

### Commands

```zsh
ducktape-alias      # Switch agent interactively
ducktape-taping     # Enable/disable plain terminal session mode
ducktape-param      # Manage run parameters (global / local)
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

### Taping Mode

`taping` mode keeps the current directory on a plain tmux shell session instead of an agent session.
`taping` mode enables an agent → tap → shell cycle for the current directory.

```zsh
ducktape-taping --enable
ducktape-taping --show
ducktape-taping --disable
```

When enabled, `F2` first opens the agent session, then switches to the tap session, then detaches back to shell.

### Run Parameters

Pass flags to the agent automatically on every launch.  
Parameters have two scopes that are merged at runtime:

| Scope | File | Applied when |
|-------|------|--------------|
| **global** | `~/.zsh/.ducktape-params` | every session, everywhere |
| **local** | `.ducktape-params` in `$PWD` | sessions started from that directory |

```zsh
# Global — always use yolo mode
ducktape-param global add --dangerously-skip-permissions

# Local — this project uses a specific model
ducktape-param local add --model claude-opus-4-5

# Inspect merged result
ducktape-param show
# global: --dangerously-skip-permissions
# local:  --model claude-opus-4-5  [~/my-project]
# merged: --dangerously-skip-permissions --model claude-opus-4-5

# Replace all global params at once
ducktape-param global set --dangerously-skip-permissions --verbose

# Clear
ducktape-param global clear
ducktape-param local clear
```

The local `.ducktape-params` file can be committed to a project repo or added to `.gitignore` — your choice.

> **Note for existing installs:** the F12 restart binding in `~/.tmux.conf` was written at install time and does not auto-update. Re-run the installer to get the updated binding that reads params on restart.

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
~/.zsh/.ducktape-params        # Global run parameters (optional)
$PWD/.ducktape-params          # Local run parameters per project (optional)
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
