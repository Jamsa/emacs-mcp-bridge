# emacs-mcp-bridge

MCP tools + AI-client integration that let Claude Code and Gemini CLI collaborate with a live Emacs session. Reads the buffer you're looking at, edits via Ediff review with in-place apply, and ships six ready-made text-transform helpers (`/emacs:polish`, `/emacs:to-cn`, `/emacs:to-en`, `/emacs:explain`, `/emacs:insert`, `/emacs:rewrite`).

## What's in the box

- **17 MCP tools** (`emacs-mcp-bridge.el`) — context reads, Ediff-backed merges, project intelligence, buffer/file navigation, cursor introspection, user prompts/messages
- **7 skills** (shared between Claude Code and Gemini CLI)
  - `emacs-polish`, `emacs-to-cn`, `emacs-to-en` — selection transforms
  - `emacs-explain` — read-only: explain selection or thing-at-point
  - `emacs-insert` — generate and insert content at cursor
  - `emacs-rewrite` — custom rewrite based on user instruction
  - `emacs-integration` — protocol auto-invoked whenever `mcp__emacs__*` tools are present
- **Slash-command aliases** for explicit invocation: `/emacs:polish`, `/emacs:to-cn`, `/emacs:to-en`, `/emacs:explain`, `/emacs:insert`, `/emacs:rewrite`

## Architecture

```
  ┌─────────────────────┐    stdio/MCP    ┌─────────────────────┐
  │  Claude Code        │ ◄────────────►  │                     │
  │  Gemini CLI         │                 │   Emacs             │
  │  (any MCP client)   │                 │  + emacs-mcp-server │
  └─────────────────────┘                 │  + emacs-mcp-bridge │
                                          └─────────────────────┘
```

The elisp side (the `emacs-mcp-server` package plus this bridge's `.el` file) serves MCP tools from inside Emacs. The client side (this plugin/extension) provides the skills and slash commands that use those tools.

## Installation

Three pieces. The Emacs side is required. The Claude and Gemini sides are each optional.

### 1. Emacs side (required)

#### 1a. Install `emacs-mcp-server`

This bridge depends on the [`emacs-mcp-server`](https://github.com/rhblind/emacs-mcp-server) package (which provides `mcp-server-tools-register` and the stdio transport).

**Doom Emacs** (`packages.el`):

```elisp
(package! mcp-server
  :recipe (:type git :host github :repo "rhblind/emacs-mcp-server"
           :files ("*.el" "tools/*.el" "mcp-wrapper.py" "mcp-wrapper.sh")))
```

**straight.el**:

```elisp
(straight-use-package
 '(mcp-server :type git :host github :repo "rhblind/emacs-mcp-server"
              :files ("*.el" "tools/*.el" "mcp-wrapper.py" "mcp-wrapper.sh")))
```

Then in your init:

```elisp
(use-package mcp-server
  :config
  (mcp-server-start))
```

See the upstream README for transport details (Unix socket path, wrapper script, etc.).

#### 1b. Load `emacs-mcp-bridge`

After installing the plugin, add the elisp directory to your `load-path` and require the bridge. The exact path depends on your plugin installation location (e.g., ` ~/.claude/plugins/marketplaces/emacs-mcp-bridge/elisp/emacs-mcp-bridge.el or  ~/.gemini/extensions/emacs-mcp-bridge/elisp`):

```elisp
(add-to-list 'load-path "~/path/to/emacs-mcp-bridge/elisp")
(require 'emacs-mcp-bridge)
```

Or copy `elisp/emacs-mcp-bridge.el` to a directory already on your `load-path`.

**Note:** This plugin does not register an MCP server on your behalf. You declare MCP servers in your CLI's own settings (`claude mcp add` for Claude Code, Gemini CLI's settings for Gemini), because you likely want other MCP servers too. Point your CLI at the wrapper script from `emacs-mcp-server`.

### 2. Claude Code (optional)

Install from the GitHub marketplace:

```bash
claude plugin marketplace add Jamsa/emacs-mcp-bridge
claude plugin install emacs-mcp-bridge@emacs-mcp-bridge
```

Verify:

```bash
claude plugin list
```

### 3. Gemini CLI (optional)

```bash
gemini extensions install https://github.com/Jamsa/emacs-mcp-bridge
```

Verify inside an interactive `gemini` session that `/emacs:polish` is available.

## Usage

### Slash commands — quick reference

Select a region in Emacs (or just point the cursor at something), then in your AI client:

```
/emacs:polish    # fix typos and grammar       (Ediff review)
/emacs:to-cn     # translate to Chinese        (Ediff review)
/emacs:to-en     # translate to English        (Ediff review)
/emacs:explain   # explain selection or cursor (read-only)
/emacs:insert    # insert content at cursor   (direct insert, no review)
/emacs:rewrite   # custom rewrite based on prompt (Ediff review)
```

For the transform commands, the AI proposes a change via Ediff — press `b` on each hunk to apply in-place, then `q` to quit. `/emacs:explain` is read-only; it answers in chat without touching the buffer. `/emacs:insert` inserts content directly at the cursor with no review.

### Natural language — skills auto-invoke

You don't have to remember slash commands. The skills' `description` metadata lets the AI pick the right one from what you say:

| What you type                            | Skill that fires     |
|------------------------------------------|----------------------|
| "fix the grammar in this paragraph"      | `emacs-polish`       |
| "polish this", "clean up this writing"   | `emacs-polish`       |
| "translate this to Chinese" / "中文化"    | `emacs-to-cn`        |
| "rewrite this in English"                | `emacs-to-en`        |
| "what does this function do?"            | `emacs-explain`      |
| "explain this", "what is this symbol?"   | `emacs-explain`      |
| "insert a joke here" / "add a header"    | `emacs-insert`       |
| "rewrite this to be more formal"         | `emacs-rewrite`      |
| "transform the selection", "rewrite this"| `emacs-rewrite`      |

### Example workflows

#### 1. Polish a rough paragraph (selection → in-place edit)

1. In Emacs, select a paragraph you wrote quickly.
2. Type `/emacs:polish` in the AI client.
3. Ediff opens with one hunk (your text vs. the polished version).
4. Press `b` to apply the AI change directly to your buffer.
5. Press `q` to close Ediff.

Same pattern works for `/emacs:to-cn` (any language → Chinese), `/emacs:to-en` (any language → English), and `/emacs:rewrite` (custom rewrite based on your prompt).

#### 2. Insert content at cursor

1. In Emacs, position the cursor where you want content inserted.
2. Type `/emacs:insert tell me a joke` in the AI client.
3. Content is inserted directly at the cursor — no Ediff review needed.

#### 3. Explain code without selecting it first

1. Put the cursor on a function name or symbol.
2. Type `/emacs:explain` or just ask `"what does this do?"`
3. The AI calls `get-thing-at-point` with `thing: "defun"` (or `"symbol"`) — no selection needed.
4. Answer arrives in chat. Your buffer is untouched.

#### 4. Natural-language editing

> *"Rewrite the second bullet in Chinese, but keep the technical terms like API, SDK, LLM in English."*

With a region selected, the AI routes this to `emacs-to-cn`, respects your constraint, and opens Ediff for review. No command syntax required.

#### 5. Context-first investigation (no edit)

> *"What are the sub-categories discussed in this file?"*

The AI calls `get-active-buffer-context` with `include_content: true` (because the answer needs the full file), scans, and replies. Your buffer is read-only to it unless you say otherwise.

#### 6. Interactive dialog with `prompt-user`

> *"Refactor this function — I want to extract the validation logic."*

The AI, if uncertain, can call `prompt-user` with a choice:

```
Extract validation as:  [1] standalone function   [2] inline helper   [3] cancel
```

You pick in the Emacs minibuffer; the AI proceeds with your choice and opens Ediff on the result.

#### 7. Status without chat noise — `message-user`

After applying a multi-step edit, the AI can call `message-user` with `"Applied 3 fixes across lines 42, 87, 104"`. You see it in the Emacs echo area; the chat stays clean.

### Common recipes in one line

```text
Select → /emacs:polish       # fix up rough prose
Select → /emacs:to-cn        # localize an English note
Select → /emacs:rewrite      # custom rewrite with your prompt
Cursor → /emacs:insert       # insert generated content at cursor
Cursor on identifier → /emacs:explain
"Where is TransactionMonitor defined?"       # triggers list-files-in-project + search
"Add a docstring to this function"           # triggers interactive-merge-selection
"Fix the Flycheck error on line 42"          # uses get-diagnostics + interactive-merge
```

### Tips

- **Keep selections tight.** A selection is "explicit scope" — the AI will stay inside it. Select exactly the paragraph or function you want edited.
- **Cursor-only works for read-only skills.** `/emacs:explain` is happiest with just the cursor placed on what you want explained. Saves the "please select first" round-trip.
- **Use `b` on every hunk before `q`.** Quitting Ediff without pressing `b` discards the change — the AI can't tell; it just assumes you applied it.
- **Chain naturally.** "Polish this, then translate the polished version to Chinese." The AI runs `emacs-polish` → waits → runs `emacs-to-cn` on the new selection.

## MCP tool reference

| Tool | Purpose |
|------|---------|
| `get-active-buffer-context` | Return the focused buffer's metadata + selection. Pass `include_content: true` to also get the full buffer content. |
| `get-thing-at-point` | Return the word/symbol/sexp/defun/line/sentence/paragraph/url at cursor, with bounds |
| `open-file-at-location` | Open a file and jump to line/column |
| `insert-at-point` | Insert text at the cursor |
| `replace-selection` | Directly replace the selection (no review) |
| `interactive-merge-selection` | Ediff the selection against proposed text; `b` applies in-place |
| `interactive-merge-buffer` | Ediff a named buffer against proposed content |
| `interactive-merge-file` | Ediff a file on disk against proposed content |
| `prompt-user` | Ask the user a question via the minibuffer; blocks until they answer |
| `message-user` | Show a one-line status in the echo area (no chat noise) |
| `list-buffers` | List all open buffers |
| `switch-to-buffer` | Switch to a named buffer |
| `get-project-root` | Return the current project root |
| `list-files-in-project` | List tracked project files |
| `describe-symbol` | Return elisp documentation for a symbol |
| `search-buffer` | Regex search in the current buffer |
| `recent-files` | List recently opened files |

All three `interactive-merge-*` tools apply changes **in-place** to the original buffer/file when the user presses `b` in Ediff.

## Development

### Local development setup

For local development, you can install from the local path:

**Claude Code:**
```bash
# Register the local marketplace
claude plugin marketplace add /path/to/emacs-mcp-bridge

# Install the plugin
claude plugin install emacs-mcp-bridge@emacs-mcp-bridge
```

**Gemini CLI:**
```bash
# Symlink for live development (edits are immediately live)
gemini extensions link /path/to/emacs-mcp-bridge --consent
```

**Emacs elisp path:** After installing, load the bridge:
```elisp
(add-to-list 'load-path "/path/to/emacs-mcp-bridge/elisp")
(require 'emacs-mcp-bridge)
```

### Reloading after edits

Edit elisp code in place and reload:
```
M-x load-file RET /path/to/emacs-mcp-bridge/elisp/emacs-mcp-bridge.el RET
```

For Claude Code structural changes, run:
```
claude plugin marketplace update emacs-mcp-bridge
```

For Gemini CLI, the symlinked extension is immediately live.

## License

MIT — see `LICENSE`.
