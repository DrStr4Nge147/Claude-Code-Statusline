# install-statusline.ps1
# One-click installer for Claude Code colored status line.
# Safe to run on machines that already have a ~/.claude/settings.json —
# it only adds/updates the "statusLine" key, leaving everything else intact.

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$claudeDir   = Join-Path $HOME ".claude"
$scriptDest  = Join-Path $claudeDir "statusline-command.sh"
$settingsDest = Join-Path $claudeDir "settings.json"

# ---------------------------------------------------------------------------
# Ensure ~/.claude exists
# ---------------------------------------------------------------------------
if (-not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Path $claudeDir | Out-Null
    Write-Host "Created $claudeDir"
}

# ---------------------------------------------------------------------------
# Write statusline-command.sh
# ---------------------------------------------------------------------------
$bashScript = @'
#!/usr/bin/env bash
# Claude Code status line script - colored, multi-section design

input=$(cat)

# ---------------------------------------------------------------------------
# ANSI color helpers
# ---------------------------------------------------------------------------
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

# Foreground colors
FG_WHITE="\033[97m"
FG_CYAN="\033[36m"
FG_BRIGHT_CYAN="\033[96m"
FG_YELLOW="\033[33m"
FG_BRIGHT_YELLOW="\033[93m"
FG_GREEN="\033[32m"
FG_BRIGHT_GREEN="\033[92m"
FG_RED="\033[31m"
FG_BRIGHT_RED="\033[91m"
FG_MAGENTA="\033[35m"
FG_BRIGHT_MAGENTA="\033[95m"
FG_GRAY="\033[90m"

# Separator character
SEP="${FG_GRAY}|${RESET}"

# ---------------------------------------------------------------------------
# Parse JSON via Python (jq not available on Windows)
# ---------------------------------------------------------------------------
parsed=$(echo "$input" | python -c "
import sys, json, time
from datetime import datetime, timezone

def parse_resets_at(value):
    '''Accept either a Unix timestamp (int/float) or an ISO 8601 string.
    Returns seconds since epoch as a float, or None on failure.'''
    if value is None:
        return None
    # Numeric type: use directly
    if isinstance(value, (int, float)):
        return float(value)
    # String: try numeric first, then ISO 8601
    s = str(value).strip()
    try:
        return float(s)
    except ValueError:
        pass
    # Remove trailing Z and replace with +00:00 for fromisoformat compat
    iso = s.rstrip('Z')
    if s.endswith('Z'):
        iso += '+00:00'
    try:
        dt = datetime.fromisoformat(iso)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.timestamp()
    except ValueError:
        pass
    # Last resort: try common format without timezone
    for fmt in ('%Y-%m-%dT%H:%M:%S.%f', '%Y-%m-%dT%H:%M:%S'):
        try:
            dt = datetime.strptime(iso.split('+')[0].split('-0')[0], fmt)
            dt = dt.replace(tzinfo=timezone.utc)
            return dt.timestamp()
        except ValueError:
            continue
    return None

try:
    d = json.load(sys.stdin)
    cwd    = d.get('workspace', {}).get('current_dir', '') or d.get('cwd', '')
    model  = d.get('model', {}).get('display_name', 'Unknown')
    cw     = d.get('context_window', {})
    used   = cw.get('used_percentage')
    now    = time.time()
    rl     = d.get('rate_limits', {})

    # 5-hour limit: compute remaining time
    five_h_str = ''
    five_h_data = rl.get('five_hour')
    if five_h_data is not None:
        epoch = parse_resets_at(five_h_data.get('resets_at'))
        if epoch is not None:
            secs_left = max(0, epoch - now)
            hours_left = int(secs_left // 3600)
            mins_left  = int((secs_left % 3600) // 60)
            if hours_left >= 1:
                five_h_str = str(hours_left) + 'h'
            else:
                five_h_str = str(mins_left) + 'm'

    # 7-day limit: compute remaining days (ceiling so 1-86399s shows '1d')
    seven_d_str = ''
    seven_d_data = rl.get('seven_day')
    if seven_d_data is not None:
        epoch = parse_resets_at(seven_d_data.get('resets_at'))
        if epoch is not None:
            secs_left = max(0, epoch - now)
            if secs_left == 0:
                days_left = 0
            else:
                import math
                days_left = math.ceil(secs_left / 86400)
            seven_d_str = str(days_left) + 'd'

    # used_pct for context bar
    def fmt(v): return '' if v is None else str(round(v))

    # also pass used_percentage for coloring the rate limit labels
    five_h_pct  = five_h_data.get('used_percentage')  if five_h_data  else None
    seven_d_pct = seven_d_data.get('used_percentage') if seven_d_data else None

    print(cwd)
    print(model)
    print(fmt(used))
    print(five_h_str)
    print(seven_d_str)
    print(fmt(five_h_pct))
    print(fmt(seven_d_pct))
except Exception as e:
    print(''); print('Unknown'); print(''); print(''); print(''); print(''); print('')
" 2>/dev/null | tr -d '\r')

cwd=$(echo "$parsed"       | sed -n '1p')
model=$(echo "$parsed"     | sed -n '2p')
used_pct=$(echo "$parsed"  | sed -n '3p')
five_remain=$(echo "$parsed"  | sed -n '4p')
seven_remain=$(echo "$parsed" | sed -n '5p')
five_pct=$(echo "$parsed"  | sed -n '6p')
seven_pct=$(echo "$parsed" | sed -n '7p')

# ---------------------------------------------------------------------------
# Folder + git branch
# ---------------------------------------------------------------------------
cwd_norm=$(echo "$cwd" | tr '\\' '/' | sed 's|/$||')
folder=$(basename "$cwd_norm")
[ -z "$folder" ] || [ "$folder" = "." ] && folder="~"

git_branch=""
if [ -n "$cwd_norm" ]; then
  git_branch=$(git -C "$cwd_norm" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
fi

# ---------------------------------------------------------------------------
# Build a mini progress bar (12 chars wide) with color based on percentage
# ---------------------------------------------------------------------------
build_bar() {
  local pct="${1:-0}"
  local width=12
  local filled=$(echo "$pct $width" | awk '{printf "%d", ($1/100)*$2 + 0.5}')
  [ "$filled" -gt "$width" ] && filled=$width
  local empty=$((width - filled))

  # Color: green Ã¢â€ â€™ yellow Ã¢â€ â€™ red
  local color
  if   [ "$pct" -ge 80 ]; then color="$FG_BRIGHT_RED"
  elif [ "$pct" -ge 50 ]; then color="$FG_BRIGHT_YELLOW"
  else                          color="$FG_BRIGHT_GREEN"
  fi

  # Use printf to write block chars by codepoint Ã¢â‚¬" immune to file-encoding issues
  local FULL; FULL=$(printf '\xe2\x96\x88')   # U+2588 Ã¢â€“Ë†
  local LITE; LITE=$(printf '\xe2\x96\x91')   # U+2591 Ã¢â€“â€˜
  local bar=""
  for ((i=0; i<filled; i++)); do bar="${bar}${FULL}"; done
  for ((i=0; i<empty;  i++)); do bar="${bar}${LITE}"; done

  printf "%b%s%b" "$color" "$bar" "$RESET"
}

# ---------------------------------------------------------------------------
# Section 1 Ã¢â‚¬" Folder (bright cyan, bold) + git branch (yellow)
# ---------------------------------------------------------------------------
section_dir="${BOLD}${FG_BRIGHT_CYAN}${folder}${RESET}"
if [ -n "$git_branch" ]; then
  section_dir="${section_dir} ${FG_GRAY}on${RESET} ${FG_BRIGHT_YELLOW}${git_branch}${RESET}"
fi

# ---------------------------------------------------------------------------
# Section 2 Ã¢â‚¬" Model (magenta)
# ---------------------------------------------------------------------------
section_model="${FG_BRIGHT_MAGENTA}${model}${RESET}"

# ---------------------------------------------------------------------------
# Section 3 Ã¢â‚¬" Context window bar + percentage
# ---------------------------------------------------------------------------
section_ctx=""
if [ -n "$used_pct" ]; then
  bar=$(build_bar "$used_pct")
  # Pick label color to match bar
  if   [ "$used_pct" -ge 80 ]; then pct_color="$FG_BRIGHT_RED"
  elif [ "$used_pct" -ge 50 ]; then pct_color="$FG_BRIGHT_YELLOW"
  else                               pct_color="$FG_BRIGHT_GREEN"
  fi
  section_ctx="${FG_GRAY}ctx${RESET} ${bar} ${pct_color}${used_pct}%${RESET}"
fi

# ---------------------------------------------------------------------------
# Section 4 - Subscription rate limits (5h and/or 7d)
# pc = percentage color: green -> yellow -> red as usage grows (limit warning)
# tc = time color:       green -> yellow -> red as time shrinks (urgency warning)
# ---------------------------------------------------------------------------
section_rate=""
rate_parts=()

if [ -n "$five_remain" ] && [ "$five_remain" != "0m" ]; then
  if   [ -n "$five_pct" ] && [ "$five_pct" -ge 80 ]; then pc="$FG_BRIGHT_RED"
  elif [ -n "$five_pct" ] && [ "$five_pct" -ge 50 ]; then pc="$FG_BRIGHT_YELLOW"
  else                                                      pc="$FG_BRIGHT_GREEN"
  fi
  if   [ -n "$five_pct" ] && [ "$five_pct" -gt 96 ]; then tc="$FG_BRIGHT_GREEN"
  elif [ -n "$five_pct" ] && [ "$five_pct" -gt 80 ]; then tc="$FG_BRIGHT_YELLOW"
  else                                                      tc="$FG_BRIGHT_RED"
  fi
  rate_parts+=("${FG_GRAY}5h${RESET} ${pc}${five_pct}%  ${tc}${five_remain}${RESET}")
fi

if [ -n "$seven_remain" ] && [ "$seven_remain" != "0d" ]; then
  if   [ -n "$seven_pct" ] && [ "$seven_pct" -ge 80 ]; then pc="$FG_BRIGHT_RED"
  elif [ -n "$seven_pct" ] && [ "$seven_pct" -ge 50 ]; then pc="$FG_BRIGHT_YELLOW"
  else                                                       pc="$FG_BRIGHT_GREEN"
  fi
  if   [ -n "$seven_pct" ] && [ "$seven_pct" -gt 96 ]; then tc="$FG_BRIGHT_GREEN"
  elif [ -n "$seven_pct" ] && [ "$seven_pct" -gt 80 ]; then tc="$FG_BRIGHT_YELLOW"
  else                                                       tc="$FG_BRIGHT_RED"
  fi
  rate_parts+=("${FG_GRAY}7d${RESET} ${pc}${seven_pct}%  ${tc}${seven_remain}${RESET}")
fi

if [ "${#rate_parts[@]}" -gt 0 ]; then
  section_rate="${rate_parts[0]}"
  if [ "${#rate_parts[@]}" -gt 1 ]; then
    section_rate="${section_rate}  ${rate_parts[1]}"
  fi
fi

# ---------------------------------------------------------------------------
# Assemble all sections separated by a dim pipe
# ---------------------------------------------------------------------------
parts=("$section_dir" "$section_model")
[ -n "$section_ctx"  ] && parts+=("$section_ctx")
[ -n "$section_rate" ] && parts+=("$section_rate")

output=""
for part in "${parts[@]}"; do
  if [ -z "$output" ]; then
    output="$part"
  else
    output="${output}  ${SEP}  ${part}"
  fi
done

printf "%b" "$output"
'@

# Write with Unix line endings (LF only) so bash can execute it on Windows/WSL
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$lf = $bashScript -replace "`r`n", "`n" -replace "`r", "`n"
[System.IO.File]::WriteAllText($scriptDest, $lf, $utf8NoBom)
Write-Host "Wrote $scriptDest"

# ---------------------------------------------------------------------------
# Merge statusLine into settings.json without clobbering existing keys
# ---------------------------------------------------------------------------
$statusLineBlock = [ordered]@{
    type            = "command"
    command         = "bash ~/.claude/statusline-command.sh"
    refreshInterval = 10
}

if (Test-Path $settingsDest) {
    # Load existing settings
    $raw = Get-Content $settingsDest -Raw -Encoding UTF8
    # Strip UTF-8 BOM if present (Windows PowerShell 5 may have written one)
    $raw = $raw -replace "^\xef\xbb\xbf", ""
    try {
        $settings = $raw | ConvertFrom-Json
    } catch {
        Write-Error "Could not parse $settingsDest as JSON. Please fix it manually and re-run."
        exit 1
    }

    # ConvertFrom-Json returns a PSCustomObject; add/overwrite only statusLine
    if ($settings.PSObject.Properties.Name -contains "statusLine") {
        $settings.statusLine = $statusLineBlock
        Write-Host "Updated existing statusLine key in settings.json"
    } else {
        $settings | Add-Member -NotePropertyName "statusLine" -NotePropertyValue $statusLineBlock
        Write-Host "Added statusLine key to existing settings.json"
    }

    $json = ($settings | ConvertTo-Json -Depth 10 -Compress |
            python -c "import sys,json; print(json.dumps(json.loads(sys.stdin.read()), indent=4))") -join "`n"
} else {
    # No settings.json yet — create a minimal one
    $newSettings = [ordered]@{ statusLine = $statusLineBlock }
    $json = ($newSettings | ConvertTo-Json -Depth 10 -Compress |
            python -c "import sys,json; print(json.dumps(json.loads(sys.stdin.read()), indent=4))") -join "`n"
    Write-Host "Created new settings.json with statusLine"
}

# Write WITHOUT BOM — both PowerShell 5 and 7 safe
[System.IO.File]::WriteAllText($settingsDest, $json, $utf8NoBom)

Write-Host ""
Write-Host "Done! Restart Claude Code to see your new status line."
