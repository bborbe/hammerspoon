# hammerspoon

Minimal macOS app launcher built on [Hammerspoon](https://www.hammerspoon.org/).

`⌥ Space` → contains-search every installed app → `Enter` launches, `Esc` closes.

~50 lines of Lua. No Xcode, no compile, no Spotlight dependency, no account, no paid tier. Replaces Alfred / Raycast / Quicksilver / Spotlight for the "I just want to launch an app" use case.

## Install

```bash
brew install --cask hammerspoon
git clone git@github.com:bborbe/hammerspoon.git ~/.hammerspoon
```

Launch **Hammerspoon** once from `/Applications`, grant **Accessibility** permission when prompted (System Settings → Privacy & Security → Accessibility → Hammerspoon ✓).

You should see a "Launcher ready: ⌥ Space" toast.

## Usage

| Action | Key |
|---|---|
| Open launcher | `⌥ Space` |
| Filter results | Type (contains-match on app name) |
| Launch selected | `Enter` |
| Launch by typed name (no match) | `Enter` → falls back to `open -a "<query>"` |
| Close launcher | `Esc` |

## How It Works

| Piece | Hammerspoon API |
|---|---|
| Floating search panel | `hs.chooser` (built-in Spotlight-style UI) |
| Global hotkey | `hs.hotkey.bind({"alt"}, "space", ...)` |
| App discovery | `find -name "*.app"` over `/Applications` + `/System/Applications` + `~/Applications` + an explicit allowlist for Finder (the only user-facing app in `/System/Library/CoreServices`) |
| Fallback launch | `open -a "<query>"` when no chooser match (LaunchServices resolves by display name) |
| App icons | `hs.image.iconForFile(path)` |
| Launch | `hs.application.launchOrFocus(path)` (focuses if already running) |

No Spotlight dependency — works even when `mdutil -s /` reports "Indexing disabled".

## Customize

Edit `~/.hammerspoon/init.lua` then reload via the Hammerspoon menubar icon → *Reload Config*.

**Change the hotkey** — replace `{"alt"}, "space"` with e.g. `{"ctrl"}, "space"`.

**Add more system apps to the allowlist** — extend the `extraApps` table:

```lua
local extraApps = {
  "/System/Library/CoreServices/Finder.app",
  "/System/Library/CoreServices/Screen Time.app",
}
```

**Widen the result list** — bump `chooser:rows(8)` and `chooser:width(30)`.

## Why Hammerspoon

The hard parts of building a launcher — floating non-activating panel, focus restore, global hotkey via Carbon, substring matcher, result-list rendering — are all already solved inside `hs.chooser` and `hs.hotkey`. The user-facing surface is just policy.

Tried before settling on this:
- **Alfred 5** — Powerpack is paid, UI aging
- **Raycast** — closed-source, account required, AI/Pro upsell
- **LaunchBar** — paid, smaller ecosystem
- **Quicksilver** — FOSS but UI is early-2010s, plugins largely abandoned
- **Albert** — GPL, but macOS is community-maintained second-class
- **Ueli** — MIT but Electron
- **Kando** — pie-menu paradigm (complement, not replacement)
- **Build my own in Swift / Tauri / Go** — ~weekend of work to reproduce what `hs.chooser` already gives you

For the exact spec "hotkey → contains-search apps → Enter launches, Esc closes", Hammerspoon is the lowest-cost solution with the most upside (every other Hammerspoon capability — window management, clipboard, system event automation — comes free).

## License

MIT
