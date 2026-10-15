-- The small ✨ button that appears after you select text with the mouse.
-- Click it for a quick menu: Fix mistakes / Rewrite / Shorter / Friendlier / To English.
local M = {}
local ev = hs.eventtap.event
local T = ev.types

local ITEMS = {
  { "proofread", "Fix mistakes" },
  { "rewrite",   "Rewrite" },
  { "shorter",   "Shorter" },
  { "friendly",  "Friendlier" },
  { "translate", "Any language → English" },
}
local canvas, fadeTimer, tap
local down = nil            -- { pos, winId, winFrame }
local target = nil          -- { app, win } captured when the button appears
local BTN = 30

local function dark() return hs.host.interfaceStyle() == "Dark" end
local function colors()
  if dark() then
    return { bg = { hex = "#2c2c2a" }, line = { hex = "#4a4a46" }, text = { hex = "#ecebe6" }, hi = { hex = "#1e3350" } }
  end
  return { bg = { hex = "#ffffff" }, line = { hex = "#d6d5cf" }, text = { hex = "#1f1f1d" }, hi = { hex = "#e6effb" } }
end

local function hide()
  if fadeTimer then fadeTimer:stop(); fadeTimer = nil end
  if canvas then canvas:delete(); canvas = nil end
end
M.hide = hide

local function inside(f, p) return f and p.x >= f.x and p.x <= f.x + f.w and p.y >= f.y and p.y <= f.y + f.h end

local function startFade(sec)
  if fadeTimer then fadeTimer:stop() end
  fadeTimer = hs.timer.doAfter(sec, function()
    if canvas then canvas:hide(0.25) end
    fadeTimer = hs.timer.doAfter(0.3, hide)
  end)
end

local function choose(mode)
  local t = target
  hide()
  if t and M.onChoose then M.onChoose(mode, t.app, t.win) end
end

local function showMenu()
  if not canvas then return end
  local c = colors()
  local f = canvas:frame()
  local rowH, w = 28, 176
  local h = #ITEMS * rowH + 10
  local sf = hs.screen.mainScreen():frame()
  local x = math.min(f.x, sf.x + sf.w - w - 8)
  local y = math.min(f.y, sf.y + sf.h - h - 8)
  canvas:frame({ x = x, y = y, w = w, h = h })
  local els = {
    { type = "rectangle", action = "strokeAndFill", fillColor = c.bg, strokeColor = c.line, strokeWidth = 1,
      roundedRectRadii = { xRadius = 9, yRadius = 9 }, frame = { x = 0.5, y = 0.5, w = w - 1, h = h - 1 } },
  }
  for i, it in ipairs(ITEMS) do
    local top = 5 + (i - 1) * rowH
    table.insert(els, { id = "row" .. i, type = "rectangle", action = "fill", fillColor = { alpha = 0 },
      roundedRectRadii = { xRadius = 6, yRadius = 6 }, frame = { x = 5, y = top, w = w - 10, h = rowH },
      trackMouseDown = true, trackMouseEnterExit = true })
    table.insert(els, { type = "text", text = it[2],
      textColor = c.text, textSize = 13, frame = { x = 14, y = top + 5, w = w - 24, h = rowH } })
  end
  canvas:replaceElements(els)
  canvas:mouseCallback(function(_, msg, id)
    local i = id and tonumber(tostring(id):match("^row(%d+)$"))
    if not i then return end
    if msg == "mouseEnter" then canvas[i * 2].fillColor = c.hi
    elseif msg == "mouseExit" then canvas[i * 2].fillColor = { alpha = 0 }
    elseif msg == "mouseDown" then choose(ITEMS[i][1]) end
  end)
  startFade(8)
end

local function showButton(p)
  hide()
  local c = colors()
  canvas = hs.canvas.new({ x = p.x + 10, y = p.y - BTN - 12, w = BTN, h = BTN })
  canvas:level(hs.canvas.windowLevels.popUpMenu)
  canvas:clickActivating(false)            -- clicking it does NOT steal focus from your app
  canvas:behavior({ "canJoinAllSpaces", "transient" })
  canvas:appendElements(
    { id = "btn", type = "circle", action = "strokeAndFill", fillColor = c.bg, strokeColor = c.line, strokeWidth = 1,
      center = { x = BTN / 2, y = BTN / 2 }, radius = BTN / 2 - 1, trackMouseDown = true },
    { type = "text", text = "✨", textSize = 15, textAlignment = "center",
      frame = { x = 0, y = 5, w = BTN, h = BTN } }
  )
  canvas:mouseCallback(function(_, msg, id) if msg == "mouseDown" and id == "btn" then showMenu() end end)
  canvas:alpha(0):show():alpha(1)
  startFade(3)
end

-- Chrome and Electron apps (Slack, Claude, WhatsApp…) only report selected text to other apps
-- after their accessibility mode is switched on. Do that once per app.
local axEnabled = {}
local function enableAX(app)
  local pid = app:pid()
  if axEnabled[pid] then return end
  axEnabled[pid] = true
  pcall(function()
    local axApp = hs.axuielement.applicationElement(app)
    axApp:setAttributeValue("AXManualAccessibility", true)          -- Electron + Chromium
    local bid = app:bundleID() or ""
    if bid:find("Chrome") or bid:find("Browser") or bid:find("edgemac") then
      axApp:setAttributeValue("AXEnhancedUserInterface", true)      -- Chromium browsers
    end
  end)
end
M.enableAX = enableAX

-- Is there really some selected text? (Only then is the ✨ button shown.)
local function hasSelection(app)
  enableAX(app)
  local ok, sel = pcall(function()
    local axApp = hs.axuielement.applicationElement(app)
    local el = axApp:attributeValue("AXFocusedUIElement")
    if not el then return nil end
    local s = el:attributeValue("AXSelectedText")
    if s == nil or s == "" then
      -- web pages: the selection can live on the page itself rather than the focused field
      local parent = el
      for _ = 1, 6 do
        parent = parent and parent:attributeValue("AXParent")
        if not parent then break end
        if parent:attributeValue("AXRole") == "AXWebArea" then s = parent:attributeValue("AXSelectedText"); break end
      end
    end
    return s
  end)
  local result = ok and type(sel) == "string" and sel:gsub("%s", "") ~= ""
  if M.log then M.log("✨ check " .. (app:name() or "?") .. ": " .. (ok and (type(sel) == "string" and (#sel .. " chars") or tostring(sel)) or "error") .. " → " .. (result and "show" or "skip")) end
  return result
end

local function maybeShow(p, d)
  if not M.enabled() then return end
  local app = hs.application.frontmostApplication()
  if not app then return end
  local bid = app:bundleID() or ""
  if bid == "org.hammerspoon.Hammerspoon" or (M.exclude or {})[bid] or (M.exclude or {})[app:name()] then return end
  if M.panelVisible and M.panelVisible() then return end
  local win = hs.window.focusedWindow()
  -- ignore window drags (the window moved or resized while the mouse was down)
  if win and d and d.winId == win:id() and d.winFrame and not win:frame():equals(d.winFrame) then return end
  if not hasSelection(app) then return end
  target = { app = app, win = win }
  showButton(p)
end

function M.start()
  if tap then tap:stop() end
  tap = hs.eventtap.new({ T.leftMouseDown, T.leftMouseUp, T.keyDown, T.scrollWheel, T.rightMouseDown }, function(e)
    local t = e:getType()
    if t == T.leftMouseDown then
      local p = hs.mouse.absolutePosition()
      if canvas and inside(canvas:frame(), p) then return false end
      hide()
      local w = hs.window.focusedWindow()
      down = { pos = p, winId = w and w:id(), winFrame = w and w:frame() }
    elseif t == T.leftMouseUp then
      local d = down; down = nil
      if not d then return false end
      local p = hs.mouse.absolutePosition()
      local clicks = e:getProperty(ev.properties.mouseEventClickState) or 1
      local dist = math.sqrt((p.x - d.pos.x) ^ 2 + (p.y - d.pos.y) ^ 2)
      if dist > 6 or clicks >= 2 then
        M._t = hs.timer.doAfter(0.15, function() maybeShow(p, d) end)
      end
    else
      if canvas then hide() end
    end
    return false
  end)
  tap:start()
end

function M.stop() if tap then tap:stop() end; hide() end

return M
