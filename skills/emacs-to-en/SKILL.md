---
name: emacs-to-en
description: Translate or rewrite the currently selected region in Emacs into fluent, natural English. Use when the user invokes `/emacs:to-en`, asks to "translate this to English", "rewrite in English", or similar. Requires the `mcp__emacs__*` MCP tools to be available.
version: 0.1.0
license: MIT
---

# Emacs: Translate Selection to English

Rewrite the active Emacs selection in fluent, natural English.

## Steps

1. Call `mcp__emacs__get-active-buffer-context` to retrieve the active selection.
2. If `selection` is `null` or empty, stop and tell the user: "Please select a region in Emacs first."
3. Rewrite the selected text in English:
   - Aim for natural, idiomatic English — not a literal rendering
   - Preserve the original meaning and tone
   - Keep markup intact (Markdown, code blocks, inline code, URLs)
   - Keep identifier/code tokens in their original form
4. Call `mcp__emacs__interactive-merge-selection` with the English text as the `text` argument.
5. Tell the user: "Ediff is open. Press `b` to apply the change in-place, `q` to quit."

## Notes

- Pressing `b` in Ediff writes the change directly into the user's original buffer.
- Do not edit the file via `Edit`/`Write` — always use `interactive-merge-selection`.
