-- Saved data: your ignore list (words never flagged) and your last 50 results (history).
-- Both live in Hammerspoon's settings on your Mac only.
local M = {}
local IGNORE_KEY, HISTORY_KEY, MAX_HISTORY = "polish.ignore", "polish.history", 50

M.defaultIgnore = {}   -- filled from config.lua

-- ---------- ignore list ----------
function M.ignoreList()
  local list, seen = {}, {}
  for _, w in ipairs(M.defaultIgnore) do if not seen[w:lower()] then seen[w:lower()] = true; table.insert(list, w) end end
  for _, w in ipairs(hs.settings.get(IGNORE_KEY) or {}) do
    if not seen[w:lower()] then seen[w:lower()] = true; table.insert(list, w) end
  end
  return list
end

function M.userIgnore() return hs.settings.get(IGNORE_KEY) or {} end

function M.addIgnore(word)
  word = (word or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if word == "" then return false end
  local list = M.userIgnore()
  for _, w in ipairs(list) do if w:lower() == word:lower() then return true end end
  table.insert(list, word)
  hs.settings.set(IGNORE_KEY, list)
  return true
end

function M.removeIgnore(word)
  local out = {}
  for _, w in ipairs(M.userIgnore()) do if w:lower() ~= word:lower() then table.insert(out, w) end end
  hs.settings.set(IGNORE_KEY, out)
end

-- true if `text` contains any ignored word (whole word, case-insensitive)
function M.touchesIgnored(text)
  local lower = " " .. (text or ""):lower() .. " "
  for _, w in ipairs(M.ignoreList()) do
    local wl = w:lower():gsub("(%p)", "%%%1")
    if lower:find("[^%w]" .. wl .. "[^%w]") then return true end
  end
  return false
end

-- ---------- history ----------
function M.history() return hs.settings.get(HISTORY_KEY) or {} end

function M.addHistory(entry)
  if not entry or not entry.after or entry.after == "" then return end
  local list = M.history()
  table.insert(list, 1, {
    t = os.time(), app = entry.app or "", mode = entry.mode or "",
    before = (entry.before or ""):sub(1, 4000), after = entry.after:sub(1, 4000),
  })
  while #list > MAX_HISTORY do table.remove(list) end
  hs.settings.set(HISTORY_KEY, list)
end

function M.clearHistory() hs.settings.set(HISTORY_KEY, {}) end

return M
