-- Minimal Alfred-style app launcher
-- Hotkey: Option+Space → contains-search every macOS app → Enter launches, Esc closes
-- Fallback: if no chooser match, hit Enter to run `open -a <query>` (catches anything
-- the scan missed — e.g. freshly installed apps, handler URLs)

-- Explicit allowlist for apps outside the standard dirs (CoreServices is full of
-- 100+ internal system apps; only Finder is user-facing). Add more here if needed.
local extraApps = {
  "/System/Library/CoreServices/Finder.app",
}

-- Aliases — type the alias on the left to find the app on the right.
-- Each alias becomes its own searchable entry pointing at the real app's path,
-- so the real app still shows up too (alias is additive, not a rename).
local aliases = {
  vscode = "Visual Studio Code",
  -- idea = "IntelliJ IDEA",
  -- chrome = "Google Chrome",
  -- ff = "Firefox",
}

local function appList()
  local apps = {}
  local seen = {}
  local dirs = {
    "/Applications",
    "/System/Applications",
    os.getenv("HOME") .. "/Applications",
  }
  for _, dir in ipairs(dirs) do
    local p = io.popen('find "' .. dir .. '" -maxdepth 4 -name "*.app" -type d 2>/dev/null')
    if p then
      for line in p:lines() do
        if not seen[line] then
          seen[line] = true
          local name = line:match("([^/]+)%.app$")
          if name then
            table.insert(apps, {
              text = name,
              subText = line,
              path = line,
              image = hs.image.iconForFile(line),
            })
          end
        end
      end
      p:close()
    end
  end
  for _, path in ipairs(extraApps) do
    if not seen[path] then
      local f = io.open(path, "r")
      if f then
        f:close()
        seen[path] = true
        local name = path:match("([^/]+)%.app$")
        table.insert(apps, {
          text = name,
          subText = path,
          path = path,
          image = hs.image.iconForFile(path),
        })
      end
    end
  end
  -- Inject aliases as additional searchable entries pointing at the real apps.
  -- Original entry stays in the list — the alias is additive.
  local byName = {}
  for _, app in ipairs(apps) do byName[app.text] = app end
  for alias, target in pairs(aliases) do
    local app = byName[target]
    if app then
      table.insert(apps, {
        text = alias,
        subText = "→ " .. app.text,
        path = app.path,
        image = app.image,
      })
    end
  end
  table.sort(apps, function(a, b) return a.text:lower() < b.text:lower() end)
  return apps
end

-- Forward-declare so the closure below captures THIS local `chooser`, not the
-- global (nil). Without this, `chooser:query()` inside the callback errors with
-- "attempt to index a nil value (global 'chooser')" — classic Lua gotcha: the
-- right-hand side of a `local x = ...` runs before `x` itself is in scope.
local chooser
chooser = hs.chooser.new(function(choice)
  if choice then
    hs.application.launchOrFocus(choice.path)
    return
  end
  -- No selection. If the user typed something but had no match (Enter on empty
  -- result list), fall back to `open -a "<query>"` — LaunchServices resolves by
  -- display name; catches edge cases the scan missed.
  local q = chooser:query()
  if q and q ~= "" then
    local safe = q:gsub('"', '\\"')
    os.execute('open -a "' .. safe .. '" 2>/dev/null')
  end
end)
chooser:choices(appList())
chooser:searchSubText(false)  -- match on app name only, not path
chooser:rows(8)
chooser:width(30)
-- NOTE: do NOT set queryChangedCallback — it disables hs.chooser's built-in
-- substring filtering, which is exactly what we want.

-- Refresh app list every time the chooser is opened (catches new installs)
hs.hotkey.bind({"alt"}, "space", function()
  chooser:query("")
  chooser:choices(appList())
  chooser:show()
end)
