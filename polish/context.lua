-- Work out where the text is going (app or website) and pick a writing style for it.
local M = {}

local STYLES = {
  chat = {
    label = "chat",
    prompt = "A chat message to a client. Keep it short, friendly-professional and conversational. "
      .. "Do not add a formal greeting or sign-off if the writer didn't use one.",
  },
  email = {
    label = "email",
    prompt = "An email to a client. Keep the greeting and sign-off. Use complete, clear sentences and short paragraphs.",
  },
  linkedin = {
    label = "LinkedIn",
    prompt = "A LinkedIn message or post. Professional, a little warmer and personable. No hashtags unless the writer used them.",
  },
  doc = {
    label = "document",
    prompt = "Text in a document or slide. Clear and professional. Keep headings, bullet points and line breaks as they are.",
  },
}

-- website keyword (found in the browser tab/window title) -> style
local SITES = {
  { "Upwork", "chat", "Upwork" }, { "Fiverr", "chat", "Fiverr" },
  { "WhatsApp", "chat", "WhatsApp" }, { "Messenger", "chat", "Messenger" }, { "Slack", "chat", "Slack" },
  { "Telegram", "chat", "Telegram" }, { "Discord", "chat", "Discord" },
  { "Gmail", "email", "Gmail" }, { "Inbox", "email", "email" }, { "Outlook", "email", "Outlook" },
  { "LinkedIn", "linkedin", "LinkedIn" },
  { "Google Docs", "doc", "Google Docs" }, { "Google Slides", "doc", "Google Slides" }, { "Notion", "doc", "Notion" },
}

-- app bundle id -> style
local APPS = {
  ["com.tinyspeck.slackmacgap"] = { "chat", "Slack" },
  ["net.whatsapp.WhatsApp"] = { "chat", "WhatsApp" },
  ["ru.keepcoder.Telegram"] = { "chat", "Telegram" }, ["com.tdesktop.Telegram"] = { "chat", "Telegram" },
  ["com.apple.MobileSMS"] = { "chat", "Messages" },
  ["com.apple.mail"] = { "email", "Mail" }, ["com.microsoft.Outlook"] = { "email", "Outlook" },
  ["com.microsoft.Word"] = { "doc", "Word" }, ["com.microsoft.Powerpoint"] = { "doc", "PowerPoint" },
  ["com.apple.iWork.Pages"] = { "doc", "Pages" }, ["com.apple.iWork.Keynote"] = { "doc", "Keynote" },
  ["com.apple.Notes"] = { "doc", "Notes" }, ["com.apple.TextEdit"] = { "doc", "TextEdit" },
}

local BROWSERS = {
  ["com.google.Chrome"] = true, ["com.apple.Safari"] = true, ["com.microsoft.edgemac"] = true,
  ["company.thebrowser.Browser"] = true, ["com.brave.Browser"] = true, ["org.mozilla.firefox"] = true,
}

-- returns { prompt = "...", label = "Upwork chat" } or nil
function M.detect(app, win)
  if not app then return nil end
  local bid = app:bundleID() or ""
  if BROWSERS[bid] then
    local title = (win and win:title()) or ""
    for _, s in ipairs(SITES) do
      if title:lower():find(s[1]:lower(), 1, true) then
        local st = STYLES[s[2]]
        return { prompt = st.prompt, label = s[3] .. " " .. st.label }
      end
    end
    return nil
  end
  local a = APPS[bid]
  if a then
    local st = STYLES[a[1]]
    return { prompt = st.prompt, label = a[2] .. " " .. st.label }
  end
  return nil
end

return M
