-- Polish Writer — proofread and rewrite text in any Mac app, with your own AI API key.
-- Loaded from ~/.hammerspoon/init.lua with:   require("polish")
-- https://github.com/  (see README.md)

local POLISH_DIR = hs.configdir .. "/polish"

-- ---------- settings ----------
local function loadConfig()
  local path = POLISH_DIR .. "/config.lua"
  if not hs.fs.attributes(path) then path = POLISH_DIR .. "/config.example.lua" end
  local ok, cfg = pcall(dofile, path)
  if not ok then hs.alert.show("Polish Writer: config.lua has an error\n" .. tostring(cfg), 6); return {} end
  return cfg
end

local cfg = loadConfig()
if cfg.startAtLogin ~= false then hs.autoLaunch(true) end
if cfg.hideDockIcon ~= false then hs.dockIcon(false) end

-- keep the small troubleshooting log from growing
do
  local attr = hs.fs.attributes(POLISH_DIR .. "/.log")
  if attr and attr.size > 200000 then os.remove(POLISH_DIR .. "/.log") end
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

local function setKeyDialog()
  hs.focus()
  local btn, key = hs.dialog.textPrompt("API key", "Paste your API key. It's saved in your Mac's Keychain, never in a file.", "", "Save", "Cancel")
  if btn == "Save" and key and key:gsub("%s", "") ~= "" then
    if api.setKey((key:gsub("%s", ""))) then hs.alert.show("API key saved") else hs.alert.show("Couldn't save the key") end
  end
end

local function testConnection()
  hs.alert.show("Testing connection…")
  api.context = nil
  api.testConnection(cfg, function(ok, msg)
    if ok then hs.alert.show("Connected ✓  (" .. (cfg.model or "") .. ")", 3)
    else hs.alert.show("Connection failed:\n" .. msg, 6) end
  end)
end

local function editSettings()
  local path = POLISH_DIR .. "/config.lua"
  if not hs.fs.attributes(path) then hs.execute("cp '" .. POLISH_DIR .. "/config.example.lua' '" .. path .. "'") end
  hs.execute("open -t '" .. path .. "'")
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

local MODE_NAMES = { proofread = "Fixed", rewrite = "Rewrite", shorter = "Shorter", friendly = "Friendlier", translate = "To English" }
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
  table.insert(ign, { title = "Built-in list: edit in settings…", fn = editSettings })

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
    { title = "Set API key…",    fn = setKeyDialog },
    { title = "Edit settings…",  fn = editSettings },
    { title = "Test connection", fn = testConnection },
    { title = "Reload",          fn = hs.reload },
  }
end
menu:setMenu(buildMenu)

panel.prebuild()

-- first run: nudge the user to finish setup
if not api.getKey() and not (cfg.baseURL or ""):find("localhost") then
  hs.alert.show("Polish Writer: click ✍︎ in the menu bar → Set API key…", 5)
elseif (cfg.model or "") == "" then
  hs.alert.show("Polish Writer: click ✍︎ → Edit settings… and set your model", 5)
else
  hs.alert.show(paused() and "Polish Writer is paused" or ("Polish Writer ready — select text, press " .. hotkeyLabel()), 2)
end

return { menu = menu, hotkey = hotkey, button = button, panel = panel }
