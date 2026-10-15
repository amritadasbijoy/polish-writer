-- Polish Writer settings.
-- The installer copies this file to config.lua — edit config.lua (✍︎ menu → Edit settings…), save,
-- then choose ✍︎ → Reload.
-- Your API key is NOT stored here. It goes in the macOS Keychain (✍︎ → Set API key…).

return {
  -- ── AI provider ─────────────────────────────────────────────────────────
  -- Any OpenAI-compatible "chat completions" API works. Pick one and fill in baseURL + model:
  --
  --   OpenAI      baseURL = "https://api.openai.com/v1"        model = "gpt-4o-mini"
  --   DeepSeek    baseURL = "https://api.deepseek.com/v1"      model = "deepseek-chat"
  --   OpenRouter  baseURL = "https://openrouter.ai/api/v1"     model = "deepseek/deepseek-chat"
  --   Groq        baseURL = "https://api.groq.com/openai/v1"   model = "llama-3.3-70b-versatile"
  --   River       baseURL = "https://api.river.ai/v1"          model = "deepseek-ai/DeepSeek-V4.1-Flash"
  --   Ollama      baseURL = "http://localhost:11434/v1"        model = "llama3.1"   (local, no key needed)
  --
  -- Model names change over time — copy the exact model ID from your provider's dashboard or docs.
  baseURL = "https://api.openai.com/v1",
  model   = "gpt-4o-mini",
  timeout = 30,                                  -- seconds to wait for an answer

  -- ── About you (makes rewrites sound right) ──────────────────────────────
  -- One short line describing who you are and who you write to.
  aboutMe  = "a freelancer who writes to clients on chat, email and LinkedIn",
  spelling = "US",                               -- "US" or "UK"

  -- ── Shortcut ────────────────────────────────────────────────────────────
  -- Select text anywhere, press this. mods: "alt" (⌥), "cmd" (⌘), "ctrl" (⌃), "shift" (⇧)
  hotkey = { mods = { "alt" }, key = "space" },  -- ⌥ Space

  -- ── Words never flagged or changed (names, brands, product terms) ───────
  -- You can also add words from the ✍︎ menu, or with "Ignore word" on a spelling card.
  ignoreWords = { },                             -- e.g. { "Acme", "Kubernetes", "Priya" }

  -- ── ✨ button ───────────────────────────────────────────────────────────
  -- The ✨ button never appears in these apps (names as shown in the Dock):
  buttonExcludeApps = { "Finder", "Terminal", "iTerm2", "Dock", "Adobe Premiere Pro 2025", "Adobe Photoshop 2025",
                        "Final Cut Pro", "Logic Pro", "Xcode" },

  -- ── Behavior ────────────────────────────────────────────────────────────
  startAtLogin = true,                           -- start Hammerspoon (and Polish Writer) when you log in
  hideDockIcon = true,                           -- live only in the menu bar
}
