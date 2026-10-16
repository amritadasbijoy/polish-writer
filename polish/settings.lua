-- Settings window: provider, model, API key, "about me", and the Accessibility check.
-- Values are stored in Hammerspoon settings (key in the macOS Keychain) and override config.lua.
local api = require("polish.api")

local M = {}
local SETTINGS_KEY = "polish.cfg"
local wv, uc, axTimer
local W, H = 560, 610

-- user's saved settings (table) or {}
function M.saved() return hs.settings.get(SETTINGS_KEY) or {} end

-- merge saved settings over the file config
function M.apply(cfg)
  for k, v in pairs(M.saved()) do
    if v ~= nil and v ~= "" then cfg[k] = v end
  end
  return cfg
end

local function js(fn, data)
  if wv then wv:evaluateJavaScript("Settings." .. fn .. "(" .. hs.json.encode(data) .. ")") end
end

local function current()
  local cfg = M.cfg or {}
  return {
    baseURL = cfg.baseURL or "", model = cfg.model or "", aboutMe = cfg.aboutMe or "", spelling = cfg.spelling or "US",
    hasKey = api.getKey() ~= nil, ax = hs.accessibilityState(false),
  }
end

local function stopTimer() if axTimer then axTimer:stop(); axTimer = nil end end

local function onMessage(msg)
  local b = msg.body or {}
  if b.action == "ready" then
    js("load", current())
  elseif b.action == "openAX" then
    hs.accessibilityState(true)   -- shows the system prompt once
    hs.execute("open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'")
  elseif b.action == "open" then
    if type(b.url) == "string" and b.url:match("^https://") then hs.urlevent.openURL(b.url) end
  elseif b.action == "test" then
    local tmp = { baseURL = b.baseURL, model = b.model, timeout = (M.cfg or {}).timeout or 30 }
    api.overrideKey = (b.key and b.key ~= "") and b.key or nil
    api.context = nil
    api.testConnection(tmp, function(ok, out)
      api.overrideKey = nil
      js("testResult", { ok = ok, msg = ok and "" or out })
    end)
  elseif b.action == "save" then
    hs.settings.set(SETTINGS_KEY, { baseURL = b.baseURL, model = b.model, aboutMe = b.aboutMe, spelling = b.spelling })
    if b.key and b.key ~= "" then
      if not api.setKey(b.key) then return js("saved", { ok = false, msg = "Couldn't save the key to the Keychain." }) end
    end
    js("saved", { ok = true })
    hs.timer.doAfter(0.6, function() M.hide(); hs.reload() end)
  end
end

function M.show()
  if not wv then
    uc = hs.webview.usercontent.new("settings")
    uc:setCallback(function(msg)
      local ok, err = pcall(onMessage, msg)
      if not ok then hs.alert.show("Settings error: " .. tostring(err), 4) end
    end)
    local sf = hs.screen.mainScreen():frame()
    wv = hs.webview.new({ x = sf.x + (sf.w - W) / 2, y = sf.y + (sf.h - H) / 3, w = W, h = H }, {}, uc)
    wv:windowStyle({ "titled", "closable" })
      :windowTitle("Polish Writer — Settings")
      :level(hs.drawing.windowLevels.normal)
      :allowTextEntry(true)
      :deleteOnClose(true)
      :windowCallback(function(action) if action == "closing" then wv = nil; stopTimer() end end)
    local dir = POLISH_DIR or (hs.configdir .. "/polish")
    local f = io.open(dir .. "/settings.html"); wv:html(f:read("*a")); f:close()
  else
    js("load", current())
  end
  wv:show():bringToFront(true)
  hs.focus()
  local w = wv:hswindow(); if w then w:focus() end
  -- keep the Accessibility status fresh while the window is open
  stopTimer()
  axTimer = hs.timer.doEvery(2, function() js("ax", hs.accessibilityState(false)) end)
end

function M.hide()
  stopTimer()
  if wv then wv:delete(); wv = nil end
end

return M
