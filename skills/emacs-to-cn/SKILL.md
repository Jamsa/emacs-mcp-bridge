---
name: emacs-to-cn
description: Translate or rewrite the currently selected region in Emacs into fluent, natural Simplified Chinese. Use when the user invokes `/emacs:to-cn`, asks to "translate this to Chinese", "rewrite in Chinese", or similar. Requires the `mcp__emacs__*` MCP tools to be available.
version: 0.1.0
license: MIT
---

# Emacs: Translate Selection to Chinese

Rewrite the active Emacs selection in fluent, natural Simplified Chinese.

## Steps

1. Call `mcp__emacs__get-active-buffer-context` to retrieve the active selection.
2. If `selection` is `null` or empty, stop and tell the user: "Please select a region in Emacs first."
3. Translate the selected text into Simplified Chinese:
   - Aim for natural, idiomatic Chinese — not a literal word-for-word rendering
   - Preserve the original meaning, tone, and any domain-specific terminology
   - Keep markup intact (Markdown, code blocks, inline code, URLs)
   - Technical terms that are commonly untranslated (e.g., API, SDK, LLM) may stay in English
4. Call `mcp__emacs__interactive-merge-selection` with the Chinese text as the `text` argument.
5. Tell the user: "Ediff is open. Press `b` to apply the change in-place, `q` to quit."

## Notes

- Pressing `b` in Ediff writes the change directly into the user's original buffer.
- Do not edit the file via `Edit`/`Write` — always use `interactive-merge-selection`.
