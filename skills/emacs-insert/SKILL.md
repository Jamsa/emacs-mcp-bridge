---
name: emacs-insert
description: Generate content based on a prompt and insert it at the current cursor position in Emacs. Use when the user invokes `/emacs:insert` or asks to "insert" content with a specific prompt. Requires the `mcp__emacs__*` MCP tools to be available.
version: 0.1.0
license: MIT
---

# Emacs: Insert at Cursor

Generate content based on a prompt and insert it at the current cursor position in Emacs.

## Steps

1. Call `mcp__emacs__get-active-buffer-context` to verify Emacs is connected.
2. Generate content according to the user's prompt (e.g., "tell me a joke" → a joke).
3. Call `mcp__emacs__insert-at-point` with the generated text as the `text` argument.
4. Tell the user: "Content inserted at cursor."

## Notes

- Unlike `/emacs:rewrite` which transforms existing selections, this command generates new content.
- The content is inserted directly at the current cursor position (point) without Ediff review.
- The user prompt should be followed literally to generate appropriate content.