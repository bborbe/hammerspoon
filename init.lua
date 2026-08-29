-- Hammerspoon entry point. One require per feature module.
-- Add modules as you grow (windows.lua, clipboard.lua, …).

require("launcher")
require("tts")

hs.alert.show("Hammerspoon loaded")
