# Claude Code — Colored Status Line

> ⚠️ **Disclaimer**
>
> This script is provided as-is for customization and convenience. While it has been designed to be safe and non-destructive, you are strongly encouraged to **review and double-check the script before running it**, especially if you are not familiar with its contents.
>
> Running scripts from any source carries potential risks. Make sure you understand what the script does and verify it fits your environment and needs before execution.

---

A custom status line for Claude Code that shows your working directory, git branch, active model, context window usage, and subscription plan limits — all in color.

```
my-project  on main  │  Claude Sonnet 4.6  │  ctx ████████░░░░ 67%  │  5h 23%  15h  7d 41%  7d
```

---

## Status Line Sections

### 1. Working Directory + Git Branch

```
my-project  on main
```

| Part         | Color            | Description                    |
| ------------ | ---------------- | ------------------------------ |
| `my-project` | Bold bright cyan | The name of the current folder |
| `on`         | Dim gray         | Separator word                 |
| `main`       | Bright yellow    | Active git branch name         |

The git branch only appears when the current directory is inside a git repository. If you're not in a repo, only the folder name is shown.

---

### 2. Model

```
Claude Sonnet 4.6
```

| Part       | Color          | Description                                 |
| ---------- | -------------- | ------------------------------------------- |
| Model name | Bright magenta | The display name of the active Claude model |

Updates automatically if you switch models mid-session.

---

### 3. Context Window

```
ctx ████████░░░░ 67%
```

| Part           | Color                | Description                                                      |
| -------------- | -------------------- | ---------------------------------------------------------------- |
| `ctx`          | Dim gray             | Label                                                            |
| `████████░░░░` | Green / Yellow / Red | Progress bar — filled blocks show how much context has been used |
| `67%`          | Matches bar color    | Percentage of the context window consumed                        |

The bar and percentage change color as usage climbs:

| Usage     | Color  |
| --------- | ------ |
| 0 – 49%   | Green  |
| 50 – 79%  | Yellow |
| 80 – 100% | Red    |

The context window resets at the start of each new conversation.

---

### 4. Plan Usage (5-hour and 7-day limits)

```
5h 23%  15h    7d 41%  7d
```

This section shows your Claude subscription rate limits. Each limit has two numbers:

| Part  | Color                | Description                                                                           |
| ----- | -------------------- | ------------------------------------------------------------------------------------- |
| `5h`  | Dim gray             | Label for the rolling 5-hour usage window                                             |
| `23%` | Green / Yellow / Red | How much of the 5-hour allowance has been used — climbs toward red as the limit fills |
| `15h` | Green / Yellow / Red | Time remaining until the 5-hour window resets — shrinks toward red as urgency grows   |
| `7d`  | Dim gray             | Label for the rolling 7-day usage window                                              |
| `41%` | Green / Yellow / Red | How much of the 7-day allowance has been used — climbs toward red as the limit fills  |
| `7d`  | Green / Yellow / Red | Days remaining until the 7-day window resets — shrinks toward red as urgency grows    |

The two numbers use **independent** color scales with **opposite** meanings:

|                      | Green               | Yellow                 | Red                  |
| -------------------- | ------------------- | ---------------------- | -------------------- |
| **Percentage used**  | 0 – 49% used        | 50 – 79% used          | 80 – 100% used       |
| **Time until reset** | < 4% of window left | 4 – 20% of window left | > 20% of window left |

The time until reset is colored as a **lockout risk** indicator, not a countdown. If you hit 100% usage with 5 days left on the reset, you are locked out for those 5 days — so more time remaining is actually worse. The color reflects this:

* **Red** — reset is far away; hitting the limit now means a long lockout
* **Yellow** — reset is approaching; lockout risk is shrinking
* **Green** — reset is imminent; you are almost free regardless of usage

> These limits only appear on paid Claude subscriptions. If you are on the API or a plan without rolling limits, this section will be hidden.

---

## Installation

### 1. Run the installer

Open PowerShell and run:

```powershell
powershell -ExecutionPolicy Bypass -File install-statusline.ps1
```

Or right-click `install-statusline.ps1` and choose **Run with PowerShell**.

### 2. Restart Claude Code

The status line appears immediately after restart.

> **Execution policy error?** Run this once in PowerShell as Administrator, then retry:
>
> ```powershell
> Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
> ```

---

## Auto-Refresh

The status line re-runs every **10 seconds** so context usage and rate-limit numbers stay current without any key press.

---

## Safety

Your existing `settings.json` is **never overwritten**. The installer only adds or updates the `statusLine` key — all other settings are left untouched.

---

## Uninstalling

1. Delete `~/.claude/statusline-command.sh`
2. Remove the `statusLine` block from `~/.claude/settings.json`:

   ```json
   "statusLine": {
     "type": "command",
     "command": "bash ~/.claude/statusline-command.sh"
   }
   ```
3. Restart Claude Code.

---

## Requirements

* Windows 10 or later
* Claude Code installed
* Python available in PATH
* Git installed *(optional — only needed for branch display)*
