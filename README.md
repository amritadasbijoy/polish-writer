# ✍︎ Polish Writer

**Grammarly-style proofreading and rewriting in every Mac app — with your own AI API key.**

Select text anywhere (Chrome, Slack, Mail, Word, Notes, WhatsApp, the Claude app…), press **⌥ Space** or click the **✨** button, and fix it in place. No subscription, no account, no browser extension. Your text goes only to the AI provider *you* choose.

<!-- Add screenshots here, e.g. ![Fix mistakes popup](docs/fix-mistakes.png) -->

---

## Features

- **Fix mistakes** — a small popup under your selection with each mistake underlined. Click one to see the fix and a short reason, then **Accept** or **Dismiss**. Or **Accept all**.
- **Rewrite** — simple, clear, professional wording. For a short line you get **3 versions** to pick from.
- **Shorter** and **Friendlier** — one click each.
- **Any language → English** — write in your own language, get natural English.
- **Rewrite this part** — in a long result, highlight one sentence and rewrite just that.
- **Knows where you're writing** — short replies in chat apps (Slack, WhatsApp, Upwork, Fiverr…), greeting and sign-off kept in email, a bit warmer on LinkedIn, formatting kept in documents.
- **Ignore list** — names and brand words are never flagged.
- **History** — your last 50 results, one click to copy again.
- **Works with any OpenAI-compatible API** — OpenAI, DeepSeek, OpenRouter, Groq, River, or a local model with Ollama.

## Requirements

- macOS 12 or newer
- [Hammerspoon](https://www.hammerspoon.org) (free, open source — the installer can install it for you)
- An API key from any OpenAI-compatible provider (or Ollama running locally)

## Install

1. **Download** this repository: click **Code → Download ZIP**, then unzip it. (Or `git clone` it.)
2. Open **Terminal**, go to the folder and run the installer:
   ```bash
   cd ~/Downloads/polish-writer-main
   bash install.sh
   ```
   It installs Hammerspoon if needed (using Homebrew), copies Polish Writer into `~/.hammerspoon/polish`, and starts it. It does not touch anything else in your Hammerspoon setup.
3. **Allow Accessibility:** System Settings → Privacy & Security → Accessibility → turn on **Hammerspoon**. (Needed so it can copy your selection and paste the result.)
4. **Choose your AI provider:** click **✍︎** in the menu bar → **Edit settings…** → set `baseURL` and `model` → save → **✍︎ → Reload**.
5. **Add your API key:** **✍︎ → Set API key…** → paste → Save. Then **✍︎ → Test connection**.

### Provider settings

| Provider | `baseURL` | example `model` |
|---|---|---|
| OpenAI | `https://api.openai.com/v1` | `gpt-4o-mini` |
| DeepSeek | `https://api.deepseek.com/v1` | `deepseek-chat` |
| OpenRouter | `https://openrouter.ai/api/v1` | `deepseek/deepseek-chat` |
| Groq | `https://api.groq.com/openai/v1` | `llama-3.3-70b-versatile` |
| River | `https://api.river.ai/v1` | `deepseek-ai/DeepSeek-V4.1-Flash` |
| Ollama (local) | `http://localhost:11434/v1` | `llama3.1` (no key needed) |

Model names change often — copy the exact model ID from your provider's dashboard. Small, fast, cheap models work great for this.

### Manual install (without the script)

1. Install Hammerspoon and open it once.
2. Copy the `polish` folder to `~/.hammerspoon/polish`.
3. Copy `~/.hammerspoon/polish/config.example.lua` to `~/.hammerspoon/polish/config.lua` and edit it.
4. Add this line to `~/.hammerspoon/init.lua`:
   ```lua
   require("polish")
   ```
5. Hammerspoon menu → Reload Config. Then do steps 3–5 above.

## How to use

| Do this | To get |
|---|---|
| Select text → **⌥ Space** | Fix mistakes popup |
| Select text with the mouse → click **✨** | Menu: Fix mistakes · Rewrite · Shorter · Friendlier · To English |
| In the popup: **Enter** | Accept the current fix (then **Enter** again on *Apply* to put the text back) |
| **Tab** / **Delete** | Next mistake / dismiss this one |
| **More ▸** | Open the full panel with all modes and a custom instruction box |
| In the full panel: **⌘1 – ⌘5** | Switch mode |
| **1 / 2 / 3** | Pick one of the 3 rewrite options |
| **Esc** | Close without changing anything |

Nothing is ever sent or posted for you — Polish Writer only replaces the text you selected. You still press Send.

## Settings (`~/.hammerspoon/polish/config.lua`)

- `aboutMe` — one line about who you are and who you write to (e.g. *"a designer writing to clients"*). Makes rewrites sound right.
- `spelling` — `"US"` or `"UK"`.
- `hotkey` — change ⌥ Space to something else, e.g. `{ mods = {"ctrl","alt"}, key = "g" }`.
- `ignoreWords` — names and terms never to flag.
- `buttonExcludeApps` — apps where the ✨ button should never appear (video editors, design tools…).

After editing, choose **✍︎ → Reload**.

## Privacy

- Your API key is stored in the **macOS Keychain**, never in a file.
- Selected text is sent **only** to the `baseURL` you configured, and only when you trigger Polish Writer.
- History and the ignore list are stored locally in Hammerspoon's settings. Clear history any time from **✍︎ → History → Clear history**.

## Troubleshooting

- **Nothing happens on ⌥ Space** — check Accessibility is on for Hammerspoon. Another app may use ⌥ Space (ChatGPT, Raycast, Alfred, Claude); change `hotkey` in settings.
- **"Select some text first"** — the app didn't copy the selection. Click into the text and select again.
- **Text not replaced** — some apps (or read-only documents) don't accept paste. Use **Copy** instead.
- **API errors** — use **✍︎ → Test connection**. 401 = wrong key, 404 = wrong `baseURL` or model, 402 = no credit left, 429 = rate limited.
- **✨ appears where you don't want it** — add the app to `buttonExcludeApps`, or turn the button off in the ✍︎ menu.

## Uninstall

```bash
bash uninstall.sh
```
Removes Polish Writer and its Keychain entry; Hammerspoon stays installed.

## License

[MIT](LICENSE) © 2026 Amrita Chandra Das
