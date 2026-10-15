-- Grab the selected text from any app, and paste text back, keeping your clipboard safe.
local M = {}
M._timers = {}

local function saveClipboard() return hs.pasteboard.readAllData() end
local function restoreClipboard(saved)
  if saved and next(saved) then hs.pasteboard.writeAllData(saved) end
end

-- callback(text or nil)
function M.copy(callback)
  local saved = saveClipboard()
  local before = hs.pasteboard.changeCount()
  hs.eventtap.keyStroke({"cmd"}, "c", 0)
  local tries = 0
  local t
  t = hs.timer.doEvery(0.05, function()
    tries = tries + 1
    if hs.pasteboard.changeCount() ~= before then
      t:stop()
      local text = hs.pasteboard.readString()
      restoreClipboard(saved)
      callback(text)
    elseif tries >= 16 then          -- ~0.8s and nothing copied: no selection
      t:stop()
      callback(nil)
    end
  end)
  M._timers.copy = t
end

-- Paste plain text into `app` (an hs.application), replacing its selection.
local function log(s)
  local f = io.open((POLISH_DATA or POLISH_DIR or (hs.configdir .. "/polish")) .. "/.log", "a")
  if f then f:write(os.date("%H:%M:%S ") .. s .. "\n"); f:close() end
end
M.log = log

function M.paste(text, app, win)
  local saved = saveClipboard()
  hs.pasteboard.setContents(text)

  local function doPaste()
    local front = hs.application.frontmostApplication()
    local how = "keystroke"
    -- 1st choice: the app's own Edit > Paste menu (most reliable in Chrome, Word, PowerPoint)
    local target = app or front
    if target and target:selectMenuItem({"Edit", "Paste"}) then
      how = "menu"
    else
      hs.eventtap.keyStroke({"cmd"}, "v", 50000, target)   -- slower keystroke, sent to the app
    end
    local fw = hs.window.focusedWindow()
    log("paste into " .. (front and front:name() or "?") .. " window " .. tostring(fw and fw:id()) .. " (wanted " .. tostring(win and win:id()) .. ") via " .. how)
    M._timers.restore = hs.timer.doAfter(1.0, function() restoreClipboard(saved) end)
  end

  if not app then return doPaste() end
  -- go back to the exact window the text came from (Chrome often has several)
  if win and win:application() then win:focus() else
    app:activate(true)
    local w = app:focusedWindow() or app:mainWindow()
    if w then w:focus() end
  end

  -- wait (up to ~1.5s) until the app is really in front, then paste
  local tries = 0
  M._timers.paste = hs.timer.doEvery(0.05, function()
    tries = tries + 1
    local front = hs.application.frontmostApplication()
    if (front and front:pid() == app:pid()) or tries >= 30 then
      M._timers.paste:stop()
      M._timers.paste2 = hs.timer.doAfter(0.25, doPaste)   -- small extra pause so the text box regains focus
    end
  end)
end

return M
