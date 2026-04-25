# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

`emacs-mcp-bridge` is an MCP plugin that bridges AI clients (Claude Code, Gemini CLI) with a live Emacs session. It exposes 17 MCP tools — context reads, Ediff-backed in-place merges, project intelligence, and text transforms (polish/translate/explain). The user reviews AI-proposed edits in Ediff and presses `b` to apply each hunk in-place.

```
AI client (Claude Code / Gemini CLI) ←→ MCP ←→ Emacs + emacs-mcp-server + emacs-mcp-bridge.el
```

## Core elisp file

`elisp/emacs-mcp-bridge.el` — all 17 MCP tools are registered here via `mcp-server-tools-register`. Depends on the `mcp-server` package (provides the stdio transport). Edits here require `M-x load-file` to reload live.

## Ediff review UX

All write tools (`interactive-merge-selection`, `interactive-merge-buffer`, `interactive-merge-file`) open Ediff with the original as buffer A and the AI-proposed content as buffer B. Press `b` on a hunk to apply the change in-place. Press `q` to quit. **Quitting without `b` silently discards the change.**

`replace-selection` writes directly with no review — use only for trivial, unambiguous changes.

## Skills

| Skill | Purpose |
|-------|---------|
| `emacs-integration` | Auto-invoked protocol for every task when `mcp__emacs__*` tools are present |
| `emacs-polish` | Fix typos/grammar in selection |
| `emacs-to-cn` | Translate selection to Chinese |
| `emacs-to-en` | Translate selection to English |
| `emacs-explain` | Explain symbol/defun/selection at cursor |
| `emacs-insert` | Generate and insert content at cursor |
| `emacs-rewrite` | Custom rewrite based on user instruction |

## Development

Reload elisp changes live:
```
M-x load-file RET ~/devel/agent-tools/plugins/emacs-mcp-bridge/elisp/emacs-mcp-bridge.el RET
```

For Claude Code plugin changes, run:
```
claude plugin marketplace update agent-tools
```

For Gemini CLI, the extension is symlinked (`gemini extensions link`) so edits are immediately live.

## Project structure

- `elisp/emacs-mcp-bridge.el` — MCP tool implementations
- `skills/` — skill definitions (auto-invoked by AI clients)
- `commands/` — slash-command aliases (`/emacs:polish`, etc.)
- `.claude-plugin/plugin.json` — Claude Code plugin manifest
- `gemini-extension.json` — Gemini CLI extension manifest

## Dependencies

- Emacs 27.1+
- `emacs-mcp-server` package (provides `mcp-server-tools-register` and stdio transport)
- The user must have `mcp-server-start` running in their Emacs before the bridge tools will work