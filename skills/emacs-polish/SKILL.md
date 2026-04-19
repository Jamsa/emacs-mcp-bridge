---
name: emacs-polish
description: Fix typos, grammar issues, and polish writing quality of the currently selected region in Emacs. Use when the user invokes `/emacs:polish`, asks to "polish this text", "fix grammar", "improve writing", or similar edits to the active Emacs selection. Requires the `mcp__emacs__*` MCP tools to be available.
version: 0.1.0
license: MIT
---

# Emacs: Polish Selection

Fix typos, grammar, and improve writing quality of the active Emacs region.

## Steps

1. Call `mcp__emacs__get-active-buffer-context` to retrieve the focused buffer and active selection.
2. If `selection` is `null` or empty, stop and tell the user: "Please select a region in Emacs first."
3. Rewrite the selected text:
   - Fix typos and grammar errors
   - Improve clarity and flow
   - **Preserve** the original meaning, tone, and language (Chinese stays Chinese, English stays English)
   - Keep formatting conventions (Markdown, comments, indentation)
4. Call `mcp__emacs__interactive-merge-selection` with the polished text as the `text` argument.
5. Tell the user: "Ediff is open. Press `b` to apply the change in-place, `q` to quit."

## Notes

- Pressing `b` in Ediff writes the change directly into the user's original buffer. No manual apply step is needed.
- Since only the selection differs, Ediff shows exactly one hunk.
- Do not edit the file via the `Edit` or `Write` tools — always route through `interactive-merge-selection` so the user reviews.
