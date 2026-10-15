-- Floating Polish panel (a small web view) that appears near the mouse.
local selection = require("polish.selection")
local api = require("polish.api")
local context = require("polish.context")
local store = require("polish.store")

local M = {}
local W, H = 600, 400
local wv, uc
local state = { app = nil, text = "", reqId = 0 }

local function js(fn, data)
  if wv then wv:evaluateJavaScript("Polish." .. fn .. "(" .. hs.json.encode(data) .. ")") end
end

local function hide(returnFocus)
  if wv then wv:hide() end
  if returnFocus then
    if state.win and state.win:application() then state.win:focus()
    elseif state.app then state.app:activate() end
  end
end

local function onMessage(msg)
  local b = msg.body or {}
  if b.action == "run" then
    state.reqId = state.reqId + 1
    local id = state.reqId
    api.context = state.ctx and state.ctx.prompt or nil
    local VARIANT_MODES = { rewrite = true, shorter = true, friendly = true }
    local short = #state.text <= 300 and not state.text:find("\n")
    if b.mode == "proofread" and (b.extra or ""):gsub("%s", "") == "" then
      api.check(M.cfg, state.text, function(ok, out)
        if id ~= state.reqId then return end
        if not ok then return js("result", { ok = false, text = out }) end
        local kept = {}
        for _, it in ipairs(out) do if not store.touchesIgnored(it.wrong) then table.insert(kept, it) end end
        js("checkResult", { issues = kept })
      end)
    elseif VARIANT_MODES[b.mode] and short then
      api.runVariants(M.cfg, b.mode, state.text, function(ok, out)
        if id ~= state.reqId then return end
        if not ok then return js("result", { ok = false, text = out }) end
        js("result", { ok = true, text = out[1], options = out })
        if M.onResult then M.onResult(b.mode, state.text, out[1]) end
      end, b.extra)
    else
      api.run(M.cfg, b.mode, state.text, function(ok, out)
        if id ~= state.reqId then return end       -- an older request; ignore
        js("result", { ok = ok, text = out })
        if ok and M.onResult then M.onResult(b.mode, state.text, out) end
      end, b.extra)
    end
  elseif b.action == "resize" then
    if state.mini and wv then
      local f = wv:frame()
      local sf = hs.screen.mainScreen():frame()
      f.h = math.min(math.max((tonumber(b.h) or 120) + 34, 100), 460)   -- + title bar
      if f.y + f.h > sf.y + sf.h - 8 then f.y = math.max(sf.y + 8, (state.anchorY or f.y) - f.h - 30) end
      wv:frame(f)
    end
  elseif b.action == "full" then
    state.mini = false
    local f = wv:frame()
    local sf = hs.screen.mainScreen():frame()
    f.w, f.h = W, H
    f.x = math.min(f.x, sf.x + sf.w - W - 10)
    if f.y + f.h > sf.y + sf.h - 10 then f.y = math.max(sf.y + 10, sf.y + sf.h - H - 10) end
    wv:frame(f)
  elseif b.action == "part" then
    local pid = (state.partId or 0) + 1
    state.partId = pid
    api.rewritePart(M.cfg, b.part or "", b.full or "", function(ok, out)
      if pid ~= state.partId then return end
      js("partResult", { ok = ok, options = ok and out or nil, text = (not ok) and out or nil })
    end, b.extra)
  elseif b.action == "ignore" then
    if store.addIgnore(b.word) then hs.alert.show("“" .. (b.word or "") .. "” won't be flagged again", 1.5) end
  elseif b.action == "replace" then
    selection.log("replace clicked; app=" .. (state.app and state.app:name() or "nil") .. "; chars=" .. #(b.text or ""))
    store.addHistory({ app = state.app and state.app:name(), mode = b.mode, before = state.text, after = b.text })
    hide(false)
    selection.paste(b.text, state.app, state.win)
  elseif b.action == "copy" then
    store.addHistory({ app = state.app and state.app:name(), mode = b.mode, before = state.text, after = b.text })
    hs.pasteboard.setContents(b.text)
    hide(true)
    hs.alert.show("Copied", 1)
  elseif b.action == "close" then
    state.reqId = state.reqId + 1
    hide(true)
  end
end

local function build()
  uc = hs.webview.usercontent.new("polish")
  uc:setCallback(function(msg)
    local ok, err = xpcall(onMessage, debug.traceback, msg)
    if not ok then selection.log("ERROR " .. tostring(err)); hs.alert.show("Polish error — see polish/.log", 3) end
  end)
  wv = hs.webview.new({ x = 0, y = 0, w = W, h = H }, { developerExtrasEnabled = false }, uc)
  wv:windowStyle({ "titled", "closable", "fullSizeContentView" })
    :windowTitle("Polish")
    :titleVisibility("hidden")
    :level(hs.drawing.windowLevels.floating)
    :allowTextEntry(true)
    :closeOnEscape(false)
    :deleteOnClose(false)
    :shadow(true)
    :windowCallback(function(action) if action == "closing" then state.reqId = state.reqId + 1 end end)
  local f = io.open((POLISH_DIR or (hs.configdir .. "/polish")) .. "/panel.html")
  wv:html(f:read("*a")); f:close()
end

local MINI_W, MINI_H = 420, 150

local function placeNearMouse(mini)
  local p = hs.mouse.absolutePosition()
  local sf = hs.mouse.getCurrentScreen():frame()
  local w, h = W, H
  if mini then w, h = MINI_W, MINI_H end
  local x = mini and (p.x - 30) or (p.x - w / 2)
  x = math.min(math.max(x, sf.x + 10), sf.x + sf.w - w - 10)
  local y = p.y + (mini and 16 or 24)
  if y + h > sf.y + sf.h - 10 then y = math.max(p.y - h - 24, sf.y + 10) end
  state.anchorY = p.y
  wv:frame({ x = x, y = y, w = w, h = h })
end

-- Show the panel for some text that came from `app`.
-- mini = true shows the small "Fix mistakes" popup right under the selection instead of the big panel.
function M.showFor(text, app, mode, win, mini)
  if not wv then build() end
  state.text, state.app, state.win, state.mini = text, app, win, mini and true or false
  state.ctx = context.detect(app, win)
  placeNearMouse(state.mini)
  wv:show():bringToFront(true)
  hs.focus()
  local win = wv:hswindow(); if win then win:focus() end
  -- give the page a moment the very first time
  hs.timer.doAfter(0.05, function() js("open", { text = text, mode = mode or "proofread", mini = state.mini, ctx = state.ctx and state.ctx.label or "" }) end)
end

-- Hotkey entry point: copy the selection from the front app, then open the panel.
function M.isVisible() return wv and wv:isVisible() end

function M.openFromSelection(mode, app0, win0)
  local app = app0 or hs.application.frontmostApplication()
  if app and app:bundleID() == "org.hammerspoon.Hammerspoon" and wv and wv:isVisible() then return end
  local win = win0 or hs.window.focusedWindow()
  local front = hs.application.frontmostApplication()
  if app0 and front and front:pid() ~= app0:pid() and win0 then win0:focus() end
  selection.log("hotkey/button in " .. (app and app:name() or "?") .. " mode=" .. tostring(mode))
  selection.copy(function(text)
    if not text or text:gsub("%s", "") == "" then
      selection.log("  nothing copied")
      hs.alert.show("Select some text first", 1.5); return
    end
    if #text > 8000 then
      hs.alert.show("That's a lot of text. Select a few paragraphs at a time.", 2.5); return
    end
    selection.log("opened from " .. (app and app:name() or "?") .. " window " .. tostring(win and win:id()))
    M.showFor(text, app, mode, win, (mode or "proofread") == "proofread")
  end)
end

function M.prebuild() if not wv then build() end end

return M
