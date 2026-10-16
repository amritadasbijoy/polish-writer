-- Calls any OpenAI-compatible chat API (OpenAI, DeepSeek, OpenRouter, Groq, River, Ollama, ...) + the writing prompts
local M = {}
local KEYCHAIN_SERVICE = "polish-writer-api"

-- ---------- API key in macOS Keychain ----------
local function shq(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

function M.getKey()
  local out, ok = hs.execute("security find-generic-password -s " .. KEYCHAIN_SERVICE .. " -w 2>/dev/null")
  if ok and out then out = out:gsub("%s+$", "") end
  if ok and out ~= "" then return out end
  return nil
end

function M.setKey(key)
  local _, ok = hs.execute("security add-generic-password -U -a polish -s " .. KEYCHAIN_SERVICE .. " -w " .. shq(key))
  return ok
end

-- ---------- Prompts ----------
local BASE_RULES = [[
Rules:
- Use {{SPELLING}} English spelling.
- Keep the original meaning. Do not add new facts, promises, prices, dates, or deadlines.
- Keep names, numbers, links, emails, file names, and product names exactly as written.
- Keep line breaks and list formatting.
- Return ONLY the final text. No quotes, no explanations, no notes.]]

M.prompts = {
  proofread = [[You are a careful proofreader.
Fix only spelling, grammar, punctuation, and clearly wrong word choices.
Do not change the style, tone, or wording when it is already correct.
]] .. BASE_RULES,

  rewrite = [[You rewrite messages for {{WRITER}}.
Rewrite the text in simple, clear, professional English:
- Short sentences and common everyday words (no fancy words like "delve", "leverage", "utilize").
- Polite and confident, but natural, not stiff or over-formal.
- Fix all grammar and spelling mistakes.
- It should read like a real person wrote it: no repeated words close together, no robotic phrases.
- Prefer active voice ("I finished the edits" rather than "The edits have been finished").
]] .. BASE_RULES,

  shorter = [[You shorten messages for {{WRITER}}.
Make the text shorter and clearer, in simple professional English.
Remove repetition and filler, but keep every important point and request.
Fix all grammar and spelling mistakes.
]] .. BASE_RULES,

  friendly = [[You rewrite messages for {{WRITER}}.
Make the text warmer and friendlier, while staying professional and simple.
Use everyday words and a natural, positive tone. Do not overdo it or add emojis.
Fix all grammar and spelling mistakes.
]] .. BASE_RULES,

  translate = [[You translate text written in any language (or mixed with English) by {{WRITER}} into English.
Write natural, simple, professional English, the way a native speaker would write it.
Do not translate word for word. If the text is already English, just improve it the same way.
]] .. BASE_RULES,

  -- The selected text is something the writer RECEIVED; we write a NEW reply to it.
  reply = [[You write replies for {{WRITER}}.
The user's text is a message the writer RECEIVED (usually from a client). Write the writer's reply to it.
- Simple, clear, professional English; friendly and confident, not stiff. Use {{SPELLING}} English spelling.
- Answer every question and respond to every request in the message. Keep it as short as the message allows.
- Never invent facts, prices, dates, deadlines, links, or promises. Where the writer must fill something in,
  use a short placeholder in square brackets, e.g. [delivery date] or [price].
- Match the channel: a chat message needs no formal greeting or sign-off; an email keeps a greeting and sign-off.
- Write only the reply itself — no quotes, labels, or explanations.]],

  -- The selected text is a post, update, or comment; we write a NEW comment on it.
  comment = [[You write comments for {{WRITER}}.
The user's text is a post, update, or comment (for example on LinkedIn, Facebook, YouTube, a blog, or a project
dashboard / review tool). Write a comment from the writer replying to it.
- 1 to 3 sentences, genuine and specific to what the post actually says — never generic ("Great post!").
- Simple, warm, professional English. Use {{SPELLING}} English spelling. No hashtags. At most one emoji, only if natural.
- If it is feedback or a question about the writer's work, acknowledge it and say clearly what the writer will do.
- Never invent facts, numbers, or promises; use [placeholders] if needed.
- Write only the comment itself — no quotes, labels, or explanations.]],
}

M.temperature = { proofread = 0.1, rewrite = 0.6, shorter = 0.4, friendly = 0.6, translate = 0.3, reply = 0.6, comment = 0.7 }

-- Modes that write NEW text (the selection stays as it is; the result is copied, not pasted over it)
M.writeModes = { reply = true, comment = true }

-- ---------- Core call ----------
-- callback(ok, textOrError)
function M.chat(cfg, systemPrompt, userText, temperature, callback)
  local key = M.overrideKey or M.getKey()   -- overrideKey: used by Settings → Test before saving
  local isLocal = (cfg.baseURL or ""):find("localhost") or (cfg.baseURL or ""):find("127%.0%.0%.1")
  if not key and not isLocal then return callback(false, "No API key yet. Click ✍︎ in the menu bar > Set API key…") end
  if (cfg.baseURL or "") == "" or (cfg.model or "") == "" then
    return callback(false, "Base URL or model is empty. Use the menu-bar icon > Edit settings.")
  end

  -- fill in who is writing + spelling preference (from config.lua)
  systemPrompt = systemPrompt:gsub("{{WRITER}}", function() return cfg.aboutMe or "a professional writing to clients and colleagues" end)
  systemPrompt = systemPrompt:gsub("{{SPELLING}}", function() return cfg.spelling or "US" end)
  -- where the text is going (set by the panel from the app / website) and words never to touch
  if M.context and M.context ~= "" then
    systemPrompt = systemPrompt .. "\n\nWHERE THIS TEXT WILL BE USED: " .. M.context
  end
  local ignore = M.ignoreWords and M.ignoreWords() or {}
  if #ignore > 0 then
    systemPrompt = systemPrompt .. "\n\nNEVER change, correct, or flag these words/names (keep them exactly): "
      .. table.concat(ignore, ", ")
  end

  local url = cfg.baseURL:gsub("/+$", "") .. "/chat/completions"
  local body = hs.json.encode({
    model = cfg.model,
    temperature = temperature or 0.3,
    stream = false,
    messages = {
      { role = "system", content = systemPrompt },
      { role = "user", content = userText },
    },
  })
  local headers = { ["Content-Type"] = "application/json" }
  if key then headers["Authorization"] = "Bearer " .. key end

  local done = false
  local timer = hs.timer.doAfter(cfg.timeout or 30, function()
    if not done then done = true; callback(false, "No reply from the AI provider after " .. (cfg.timeout or 30) .. "s. Check your internet.") end
  end)

  hs.http.asyncPost(url, body, headers, function(status, resp)
    if done then return end
    done = true; timer:stop()
    if status < 0 then return callback(false, "Couldn't reach the AI provider. Check your internet or the base URL.") end
    local ok, data = pcall(hs.json.decode, resp or "")
    if status == 401 or status == 403 then return callback(false, "The provider rejected your API key (" .. status .. ").") end
    if status == 404 then return callback(false, "Not found (404). Check the base URL and model ID.") end
    if status == 402 then return callback(false, "Payment needed (402). Your API balance may be empty — check your provider's billing page.") end
    if status == 429 then return callback(false, "Too many requests right now (429). Wait a few seconds and press Retry.") end
    if status >= 500 then return callback(false, "The AI provider is having a problem (" .. status .. "). Try again in a minute.") end
    if status ~= 200 or not ok or not data then
      local msg = (ok and data and data.error and (data.error.message or tostring(data.error))) or tostring(resp):sub(1, 200)
      return callback(false, "API error " .. status .. ": " .. msg)
    end
    local text = data.choices and data.choices[1] and data.choices[1].message and data.choices[1].message.content
    if not text or text == "" then return callback(false, "The AI replied, but the answer was empty.") end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    callback(true, text)
  end)
end

function M.run(cfg, mode, text, callback, extra)
  local prompt = M.prompts[mode] or M.prompts.proofread
  if extra and extra:gsub("%s", "") ~= "" then
    prompt = prompt .. "\n\nExtra instruction from the user (follow it, but keep the rules above): " .. extra
  end
  M.chat(cfg, prompt, text, M.temperature[mode] or 0.3, callback)
end

-- Three alternative versions (for a short selection). callback(ok, listOrError)
function M.runVariants(cfg, mode, text, callback, extra)
  local prompt = M.prompts[mode] or M.prompts.rewrite
  if extra and extra:gsub("%s", "") ~= "" then
    prompt = prompt .. "\n\nExtra instruction from the user (follow it, but keep the rules above): " .. extra
  end
  prompt = prompt .. [==[


OUTPUT FORMAT (this replaces "return only the final text"):
Write 3 different good versions. Vary the wording and sentence structure, but all must follow the rules above.
Return ONLY a JSON array of 3 strings, for example: ["version one", "version two", "version three"]]==]
  local temp = math.min((M.temperature[mode] or 0.5) + 0.2, 1.0)
  M.chat(cfg, prompt, text, temp, function(ok, out)
    if not ok then return callback(false, out) end
    callback(true, M.parseList(out))
  end)
end

-- Turn the model's reply into a list of strings (expects a JSON array; falls back to the raw text)
function M.parseList(out)
  local json = out:match("%[.*%]")
  local okj, list = pcall(hs.json.decode, json or "")
  local clean = {}
  if okj and type(list) == "table" then
    for _, v in ipairs(list) do
      if type(v) == "string" and v:gsub("%s", "") ~= "" then table.insert(clean, (v:gsub("^%s+", ""):gsub("%s+$", ""))) end
    end
  end
  if #clean == 0 then clean = { out } end
  return clean
end

-- Rewrite only one part of a longer message. callback(ok, listOrError)
function M.rewritePart(cfg, part, full, callback, extra)
  local prompt = M.prompts.rewrite .. "\n\n"
    .. "The user selected ONE PART of a longer message and wants only that part rewritten.\n"
    .. "Rewrite ONLY the selected part so it reads better and still fits naturally into the full message "
    .. "(same tense, same person, no repeated information, keep its punctuation role in the sentence).\n"
    .. (extra and extra:gsub("%s", "") ~= "" and ("Extra instruction from the user: " .. extra .. "\n") or "")
    .. "Full message for context:\n<<<\n" .. full .. "\n>>>\n\n"
    .. "OUTPUT FORMAT (this replaces \"return only the final text\"): Return ONLY a JSON array of 3 different "
    .. "replacement strings for the selected part, e.g. [\"one\", \"two\", \"three\"]"
  M.chat(cfg, prompt, part, 0.7, function(ok, out)
    if not ok then return callback(false, out) end
    callback(true, M.parseList(out))
  end)
end

-- Grammarly-style check: list each mistake separately. callback(ok, issuesOrError)
-- issue = { wrong = "exact text", fix = "replacement", type = "spelling|grammar|punctuation|clarity", why = "..." }
function M.check(cfg, text, callback)
  local prompt = [==[You are a careful English proofreader for {{WRITER}} ({{SPELLING}} English).
Find every mistake in the user's text: spelling, grammar, punctuation, capitalization, wrong word, and clearly awkward or unclear wording.
Do NOT flag text that is already correct. Do not change names, numbers, links, or the writer's meaning.
Go through the text sentence by sentence and check every sentence start for a capital letter, and every "i" used as a word.

Return ONLY JSON in exactly this shape:
{"issues":[{"wrong":"...","fix":"...","type":"spelling|grammar|punctuation|clarity","why":"..."}]}

Rules for each issue:
- "wrong" must be copied EXACTLY from the text (same letters, case and spacing). Keep it short: just the words that change, plus a neighbor word only if needed to make it unique.
- "fix" is what should replace "wrong".
- "why" is a very short reason (under 10 words), in plain simple English.
- List issues in the order they appear. If there are no mistakes, return {"issues":[]}.]==]
  M.chat(cfg, prompt, text, 0.1, function(ok, out)
    if not ok then return callback(false, out) end
    local json = out:match("%b{}")
    local okj, data = pcall(hs.json.decode, json or "")
    if not okj or type(data) ~= "table" or type(data.issues) ~= "table" then
      return callback(false, "Couldn't read the mistakes list. Press Retry.")
    end
    local list = {}
    for _, it in ipairs(data.issues) do
      if type(it) == "table" and type(it.wrong) == "string" and type(it.fix) == "string" and it.wrong ~= "" and it.wrong ~= it.fix then
        table.insert(list, { wrong = it.wrong, fix = it.fix, type = tostring(it.type or "grammar"), why = tostring(it.why or "") })
      end
    end
    callback(true, list)
  end)
end

function M.testConnection(cfg, callback)
  M.chat(cfg, "Reply with exactly: OK", "ping", 0, callback)
end

return M
