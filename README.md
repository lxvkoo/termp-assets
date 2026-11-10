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
4. disables termp autostart and starts the daemon hidden
5. prints `termp status`

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

# restart the daemon without leaving a console window open
Start-Process (Get-Command termp).Source -ArgumentList 'start','--foreground' -WindowStyle Hidden

termp stop     # stop it
```

`termp start` (detached) and `termp enable` / `termp install` (autostart) are **not** used here — on Windows they fail with `open daemon log: ... being used by another process`. Hence the hidden `--foreground` process above.
