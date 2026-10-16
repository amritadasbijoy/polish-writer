-- Polish Writer — proofread and rewrite text in any Mac app, with your own AI API key.
-- Two ways to run it:
--   • as the standalone "Polish Writer.app" (see app/ and scripts/build-dmg.sh), or
--   • inside Hammerspoon: put this folder in ~/.hammerspoon/polish and add  require("polish")  to init.lua
-- https://github.com/amritadasbijoy/polish-writer
-- Made by Amrita Chandra Das — https://amrita.bd · https://videocutstudio.com · https://www.linkedin.com/in/amritabijoy/

-- Where the program files live, and where personal files (log, optional config.lua) go.
-- The standalone app sets these before loading; inside Hammerspoon both are ~/.hammerspoon/polish.
POLISH_DIR = POLISH_DIR or (hs.configdir .. "/polish")
POLISH_DATA = POLISH_DATA or POLISH_DIR
local BUNDLED = POLISH_BUNDLED == true

if BUNDLED then
  -- hide everything that belongs to Hammerspoon itself
  pcall(hs.menuIcon, false)
  pcall(hs.automaticallyCheckForUpdates, false)
  pcall(hs.uploadCrashData, false)
  pcall(hs.openConsoleOnDockClick, false)
  pcall(hs.closePreferences)
end

-- ---------- settings ----------
local function loadConfig()
  local path
  for _, p in ipairs({ POLISH_DATA .. "/config.lua", POLISH_DIR .. "/config.lua", POLISH_DIR .. "/config.example.lua" }) do
    if hs.fs.attributes(p) then path = p; break end
  end
  local ok, cfg = pcall(dofile, path)
  if not ok then hs.alert.show("Polish Writer: config.lua has an error\n" .. tostring(cfg), 6); return {} end
  return cfg
end

local settings = require("polish.settings")
local cfg = settings.apply(loadConfig())     -- values saved in the Settings window win
settings.cfg = cfg
if cfg.startAtLogin ~= false then hs.autoLaunch(true) end
if cfg.hideDockIcon ~= false then hs.dockIcon(false) end
hs.consoleOnTop(false)

-- keep the small troubleshooting log from growing
do
  local attr = hs.fs.attributes(POLISH_DATA .. "/.log")
  if attr and attr.size > 200000 then os.remove(POLISH_DATA .. "/.log") end
end

local api = require("polish.api")
local store = require("polish.store")
local panel = require("polish.panel")
panel.cfg = cfg
store.defaultIgnore = cfg.ignoreWords or {}
api.ignoreWords = store.ignoreList

local function paused() return hs.settings.get("polish.paused") == true end

-- ---------- hotkey: select text anywhere, press it ----------
local hk = cfg.hotkey or { mods = { "alt" }, key = "space" }
local hotkey = hs.hotkey.bind(hk.mods, hk.key, function() panel.openFromSelection("proofread") end)

-- ---------- ✨ button after mouse selection ----------
local button = require("polish.button")
button.exclude = {}
for _, name in ipairs(cfg.buttonExcludeApps or {}) do button.exclude[name] = true end
button.enabled = function() return not paused() and hs.settings.get("polish.button") ~= false end
button.panelVisible = panel.isVisible
button.onChoose = function(mode, app, win) panel.openFromSelection(mode, app, win) end
button.start()

local function applyPause()
  if paused() then hotkey:disable(); button.hide() else hotkey:enable() end
end
applyPause()

-- ---------- menu-bar icon ----------
local menu = hs.menubar.new()
local function setIcon() menu:setTitle(paused() and "✍︎·" or "✍︎") end
setIcon()
menu:setTooltip("Polish Writer — select text, then press the hotkey or click ✨")

local function hotkeyLabel()
  local sym = { alt = "⌥", cmd = "⌘", ctrl = "⌃", shift = "⇧" }
  local s = ""
  for _, m in ipairs(hk.mods) do s = s .. (sym[m] or m) end
  return s .. (hk.key == "space" and "Space" or hk.key:upper())
end

local function testConnection()
  hs.alert.show("Testing connection…")
  api.context = nil
  api.testConnection(cfg, function(ok, msg)
    if ok then hs.alert.show("Connected ✓  (" .. (cfg.model or "") .. ")", 3)
    else hs.alert.show("Connection failed:\n" .. msg, 6) end
  end)
end

-- advanced: the full config file (ignore list, excluded apps, hotkey…)
local function editConfigFile()
  local path = POLISH_DATA .. "/config.lua"
  if not hs.fs.attributes(path) then
    hs.execute("mkdir -p '" .. POLISH_DATA .. "' && cp '" .. POLISH_DIR .. "/config.example.lua' '" .. path .. "'")
  end
  hs.execute("open -t '" .. path .. "'")
  hs.alert.show("Save the file, then choose ✍︎ → Reload", 3)
end

local function addIgnoreDialog()
  hs.focus()
  local btn, word = hs.dialog.textPrompt("Ignore a word", "Polish Writer will never flag or change this word or name:", "", "Add", "Cancel")
  if btn == "Add" and word and store.addIgnore(word) then hs.alert.show("Added “" .. word .. "”") end
end

local function short(s, n)
  s = (s or ""):gsub("%s+", " ")
  if #s > n then s = s:sub(1, n) .. "…" end
  return s
end

local MODE_NAMES = { proofread = "Fixed", rewrite = "Rewrite", shorter = "Shorter", friendly = "Friendlier", translate = "To English", reply = "Reply", comment = "Comment" }
local SAMPLE = "hi john, i have went through you're document and its ready for review. let me know if any changes need."

local function buildMenu()
  local hist = {}
  for i, h in ipairs(store.history()) do
    if i > 20 then break end
    table.insert(hist, {
      title = os.date("%d %b %H:%M", h.t) .. "  ·  " .. (MODE_NAMES[h.mode] or h.mode or "") .. "  ·  " .. short(h.after, 55),
      fn = function() hs.pasteboard.setContents(h.after); hs.alert.show("Copied from history", 1.2) end,
    })
  end
  if #hist == 0 then hist = { { title = "No history yet", disabled = true } }
  else
    table.insert(hist, { title = "-" })
    table.insert(hist, { title = "Click an item to copy it.  (Keeps your last 50)", disabled = true })
    table.insert(hist, { title = "Clear history", fn = function() store.clearHistory(); hs.alert.show("History cleared") end })
  end

  local ign = { { title = "Add a word…", fn = addIgnoreDialog }, { title = "-" } }
  local userWords = store.userIgnore()
  for _, w in ipairs(userWords) do
    table.insert(ign, { title = w .. "   (click to remove)", fn = function() store.removeIgnore(w); hs.alert.show("Removed “" .. w .. "”") end })
  end
  if #userWords == 0 then table.insert(ign, { title = "Words you add will show here", disabled = true }) end
  table.insert(ign, { title = "-" })
  table.insert(ign, { title = "Built-in list: edit config file…", fn = editConfigFile })

  return {
    { title = paused() and "Polish Writer is paused" or ("Select text, then press " .. hotkeyLabel() .. " or click ✨"), disabled = true },
    { title = "-" },
    { title = "Pause", checked = paused(), fn = function() hs.settings.set("polish.paused", not paused()); applyPause(); setIcon() end },
    { title = "Show ✨ button after selecting text", checked = hs.settings.get("polish.button") ~= false,
      fn = function() hs.settings.set("polish.button", hs.settings.get("polish.button") == false); button.hide() end },
    { title = "-" },
    { title = "History", menu = hist },
    { title = "Ignore list", menu = ign },
    { title = "Try it on a sample sentence", fn = function() panel.showFor(SAMPLE, nil, "proofread", nil, false) end },
    { title = "-" },
    { title = "About Polish Writer", menu = {
        { title = "Polish Writer — made by Amrita Chandra Das", disabled = true },
        { title = "-" },
        { title = "Portfolio — amrita.bd",           fn = function() hs.urlevent.openURL("https://amrita.bd") end },
        { title = "VideoCutStudio — videocutstudio.com", fn = function() hs.urlevent.openURL("https://videocutstudio.com") end },
        { title = "LinkedIn — Amrita Chandra Das",   fn = function() hs.urlevent.openURL("https://www.linkedin.com/in/amritabijoy/") end },
        { title = "-" },
        { title = "GitHub — updates, help and source", fn = function() hs.urlevent.openURL("https://github.com/amritadasbijoy/polish-writer") end },
        { title = "-" },
        { title = "Built on Hammerspoon (MIT license) — hammerspoon.org", fn = function() hs.urlevent.openURL("https://www.hammerspoon.org") end },
    } },
    { title = "-" },
    { title = "Settings…",              fn = settings.show },
    { title = "Test connection",        fn = testConnection },
    { title = "Advanced: edit config file…", fn = editConfigFile },
    { title = "Reload",                 fn = hs.reload },
    BUNDLED and { title = "Quit Polish Writer", fn = function() hs.application.applicationForPID(hs.processInfo.processID):kill() end } or nil,
  }
end
menu:setMenu(buildMenu)

panel.prebuild()

-- first run (or setup not finished): open the Settings window
local needsKey = not api.getKey() and not (cfg.baseURL or ""):find("localhost")
if needsKey or (cfg.model or "") == "" or not hs.accessibilityState(false) then
  hs.timer.doAfter(0.8, settings.show)
else
  hs.alert.show(paused() and "Polish Writer is paused" or ("Polish Writer ready — select text, press " .. hotkeyLabel()), 2)
end

return { menu = menu, hotkey = hotkey, button = button, panel = panel }
