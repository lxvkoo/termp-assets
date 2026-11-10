# termp-assets

[termp](https://github.com/polter-dev/discord_terminal_presence) + [pi.dev](https://pi.dev) → Discord Rich Presence, with a Pi icon, on Windows 11.

## Install (one line, PowerShell)

```powershell
irm https://raw.githubusercontent.com/lxvkoo/termp-assets/main/setup.ps1 | iex
```

Then open a terminal and run `pi` — your Discord profile shows **Using Pi** with the Pi icon.

Requirements: **Discord Desktop** (the browser version can't do Rich Presence), Windows Terminal / PowerShell.

## What `setup.ps1` does

1. installs [Scoop](https://scoop.sh/) if it's missing
2. adds the `polter-dev` bucket and `scoop install termp`
3. writes this repo's [`config.toml`](config.toml) to `%APPDATA%\termp\config.toml` (old one is backed up)
4. drops a hidden launcher at `%LOCALAPPDATA%\termp\start-hidden.ps1`
5. disables termp autostart and starts the daemon hidden
6. registers the **`termp presence`** scheduled task, so presence comes back ~20s after every logon
7. prints `termp status`

## The Pi rule

```toml
[[custom_tools]]
id = "pi"
display_name = "Pi"
match = { regex = "(?i)pi-coding-agent" }
image_url = "https://raw.githubusercontent.com/lxvkoo/termp-assets/main/pi-icon.png"
```

There is no `pi.exe`: pi runs as `node.exe .../pi-coding-agent/dist/bundle/cli.js`, so the rule matches the **command line** with a regex instead of a process name. `image_url` must be a URL — local file paths are not supported.

## Everyday commands

```powershell
termp status   # daemon / discord / detected tool
termp stop     # stop the presence

# start it again, no console window left behind
powershell -NoProfile -WindowStyle Hidden -File "$env:LOCALAPPDATA\termp\start-hidden.ps1"

# remove the logon task again
Unregister-ScheduledTask -TaskName 'termp presence' -Confirm:$false
```

`termp start` (detached) and `termp enable` / `termp install` (autostart) are **not** used here — on Windows they fail with `open daemon log: ... being used by another process`. That's why the hidden `--foreground` process + scheduled task exist instead.

## The text under the tool name

`fallback_messages = ["pressing buttons", "vibecoding", "baluetsa", "hehehe"]` — one entry is picked **at random once per daemon session**, so the line only changes when the daemon restarts (`termp stop` → launcher again). For a fixed line instead, set a non-default template, e.g. `details_format = "vibecoding with {tool}"`; note that `"Using {tool}"` is the built-in default and therefore does *not* enable templating.
