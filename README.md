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
Optional `taping` bindings let F10 jump into the first bound session from a normal terminal, and cycle through saved per-directory sessions inside tmux.

## Install

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/terria1020/ducktape/main/install.sh)"
```

### Requirements

- zsh
- tmux — optional, required only for F2/F10 session features
- At least one AI agent: `claude` / `gemini` / `codex` / `cursor`
- (recommended) `fzf` — for the session picker

## Usage

### Key Bindings

| Key | Context | Action |
|-----|---------|--------|
| `F2` | Shell prompt | Attach to agent session for current directory (creates one if none exists) |
| `F2` | Inside agent | Detach → return to shell |
| `F10` | Normal terminal | Attach to the 1st path in the `ducktape-taping` list |
| `F10` | Inside agent | Cycle to the next bound directory session |
| `Ctrl-B a` | Anywhere in tmux | fzf picker for all ducktape sessions |

### Per-directory Sessions

Each directory gets its own independent session.

```
~/project-a $ F2   →  ducktape-claude-a1b2c3d4 (new)
~/project-a $ F2   →  detach
~/project-b $ F2   →  ducktape-claude-e5f6g7h8 (new, separate session)
~/project-a $ F2   →  ducktape-claude-a1b2c3d4 (re-attach existing)
```

With session bindings:

```
~/project-a $ ducktape-taping bind
~/project-b $ ducktape-taping bind
~/project-a $ F2   →  ducktape-claude-a1b2c3d4
~/project-a $ F10  →  ducktape-claude-e5f6g7h8
~/project-b $ F10  →  ducktape-claude-a1b2c3d4
~/anywhere  $ F10  →  attach to bound path #1
```

### Commands

```zsh
ducktape-alias      # Switch agent interactively
ducktape-call       # Run an explicit agent with merged params, without tmux
ducktape-taping     # Manage numbered bound directories
ducktape-jumping 1  # Attach/switch to bound path #1
ducktape-param      # Manage run parameters (global / local)
ducktape-status     # Show session status for current directory
ducktape-ls         # List all ducktape sessions
ducktape-kill       # Kill session for current directory
ducktape-kill --bind-all  # Kill all sessions from the bound directory list
ducktape-uninstall  # Remove everything
```

All user-facing commands support `--help`, `-h`, or `help`.

### Switching Agents

```zsh
ducktape-alias
# → Select from detected agents via fzf
# → Takes effect in new terminals
```

### Direct Agent Calls

Run an explicit agent with the same merged parameters that ducktape uses, without
creating or attaching to a tmux session.

```zsh
ducktape-call codex
ducktape-call claude --verbose
ducktape-call --print gemini
```

`ducktape-call <agent>` does not read or change the selected `ducktape-alias`
agent. It uses the agent name you pass to find that agent's global parameter
file, then appends the current directory's local `.ducktape-params`.

Merge order:

```text
<agent executable> <global params for agent> <local params> <extra args>
```

### Taping Bindings

`ducktape-taping` manages a numbered circular list of bound directories.
F10 from a normal terminal attaches to path #1, while F10 inside tmux moves between the bound directories in saved order.
Entries are deduplicated by path, and missing directories are pruned automatically.

```zsh
ducktape-taping bind
ducktape-taping unbind
ducktape-taping clear
ducktape-taping --show
```

Behavior:
- `bind`: add the current directory once, preserving the original order if already bound
- `unbind`: remove the current directory from the list
- `clear`: remove the entire bind list
- `--show`: print the saved order, `ducktape-jumping <number>` hints, and mark the current directory

`ducktape-jumping <number>` ignores the current directory and attaches to that numbered bound path.
If the target bound directory's agent session is not running, it is started on demand.
If the list is empty or the number is out of range, ducktape fails without creating a session for the current directory.

### Session Bar

Each ducktape session gets a tmux status bar theme derived from the full directory path hash.
The right side of the bar also shows the current and next bound directories:

```text
curr: [my-project] next: [another-project]
```

If there is no next bound directory, it is shown as `next: []`.

### Run Parameters

Pass flags to the agent automatically on every launch.  
Parameters have two scopes that are merged at runtime:

| Scope | File | Applied when |
|-------|------|--------------|
| **global** | `~/.zsh/.ducktape-params-<agent>` | every session for that agent |
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

> **Note for existing installs:** `install.sh` now replaces the ducktape block in `~/.tmux.conf` with the latest version. Re-run the installer to refresh F10 and related tmux settings.

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
~/.zsh/.ducktape-bindings      # Numbered bound directory list (optional)
~/.zsh/.ducktape-params-<agent> # Agent-specific global run parameters (optional)
$PWD/.ducktape-params          # Local run parameters per project (optional)
~/.tmux.conf                   # F2 / F10 / Ctrl-B a bindings
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
