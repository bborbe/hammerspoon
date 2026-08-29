-- TTS menu bar control for the local tts-mcp speech server.
--
-- Polls GET /state on the tts server and shows a menu bar item with:
--   * a Pause/Resume toggle (primary control)
--   * the current / last message and its sender
--   * "Open web UI" → the tts server's web page (message history + sender)
--   * "Refresh" → re-poll now
--
-- Cancel/skip is deliberately NOT in this menu — it lives on the existing
-- scripts/hotkey path (scripts/tts-skip / make skip), per the task spec.
--
-- Requires the tts-mcp server (launchd agent com.bborbe.tts-mcp). Config
-- resolution mirrors scripts/tts-skip: $TTS_MCP_CONFIG → XDG config → repo
-- config.yaml. Falls back to 127.0.0.1:12000 when nothing is readable.

local config = {
  host = "127.0.0.1",
  port = 12000,
}

local function resolve_config()
  local function read_config(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
  end

  local candidates = {}
  if os.getenv("TTS_MCP_CONFIG") then
    table.insert(candidates, os.getenv("TTS_MCP_CONFIG"))
  end
  local xdg = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config"))
    .. "/tts-mcp/config.yaml"
  table.insert(candidates, xdg)
  table.insert(candidates, os.getenv("HOME") .. "/Documents/workspaces/tts-mcp/config.yaml")

  for _, path in ipairs(candidates) do
    local content = read_config(path)
    if content then
      local host = content:match("^host:%s*([%w%.%-]+)")
      local port = content:match("^port:%s*(%d+)")
      if host and host ~= "0.0.0.0" then config.host = host end
      if port then config.port = tonumber(port) end
      return
    end
  end
end

local function base_url()
  return string.format("http://%s:%d", config.host, config.port)
end

local state = {
  current = nil, -- { message_id, status, text, sender, engine } or nil
  recent = {},   -- list of finished messages, newest first
  queued = 0,
  loaded = false,
}

local menubar = hs.menubar.new()
menubar:setTooltip("tts-mcp")

local function render()
  local menu = {}
  local current = state.current

  if current and (current.status == "playing" or current.status == "paused") then
    local action = current.status == "paused" and "Resume" or "Pause"
    table.insert(menu, {
      title = action,
      fn = function()
        local path = current.status == "paused" and "/resume" or "/pause"
        hs.http.asyncPost(base_url() .. path, "{}", { ["Content-Type"] = "application/json" }, function()
          refresh()
        end)
      end,
    })
  else
    table.insert(menu, { title = "Idle", disabled = true })
  end

  table.insert(menu, { title = "-" })

  if current then
    local sender = current.sender and (" [" .. current.sender .. "]") or ""
    local label = current.status == "paused" and "⏸ Paused" or "▶ " .. current.status
    table.insert(menu, { title = label .. sender, disabled = true })
    table.insert(menu, { title = current.text, disabled = true })
  else
    table.insert(menu, { title = "No message playing", disabled = true })
  end

  if #state.recent > 0 then
    table.insert(menu, { title = "-" })
    for _, m in ipairs(state.recent) do
      local sender = m.sender and (" [" .. m.sender .. "]") or ""
      table.insert(menu, {
        title = (m.status .. sender .. ": " .. m.text),
        disabled = true,
      })
    end
  end

  table.insert(menu, { title = "-" })
  table.insert(menu, {
    title = "Open web UI",
    fn = function()
      hs.openURL(base_url() .. "/")
    end,
  })
  table.insert(menu, {
    title = "Refresh",
    fn = function()
      refresh()
    end,
  })

  menubar:setMenu(menu)

  -- Icon reflects state: paused vs playing.
  if current and current.status == "paused" then
    menubar:setTitle("⏸")
  elseif current and current.status == "playing" then
    menubar:setTitle("🔊")
  elseif current then
    menubar:setTitle("…")
  else
    menubar:setTitle("🔈")
  end
end

local function refresh()
  hs.http.asyncGet(base_url() .. "/state", {}, function(status, body)
    if status ~= 200 then
      state.current = nil
      state.recent = {}
      state.loaded = false
      render()
      return
    end
    local ok, data = pcall(hs.json.decode, body)
    if not ok then
      return
    end
    state.current = data.current
    state.recent = data.recent or {}
    state.queued = data.queued or 0
    state.loaded = true
    render()
  end)
end

resolve_config()
refresh()

-- Re-poll every 2 seconds so the menu stays live without a manual refresh.
hs.timer.doEvery(2, refresh)
