---
name: emacs-rewrite
description: Rewrite the currently selected region in Emacs based on a custom user-provided instruction. Use when the user invokes `/emacs:rewrite` or asks to "rewrite this", "transform the selection", or similar with a specific instruction. Requires the `mcp__emacs__*` MCP tools to be available.
version: 0.1.0
license: MIT
---

# Emacs: Rewrite Selection

Rewrite the active Emacs selection based on a user-provided instruction.

## Steps

1. Call `mcp__emacs__get-active-buffer-context` to retrieve the focused buffer and active selection.
2. If `selection` is `null` or empty, stop and tell the user: "Please select a region in Emacs first."
3. Rewrite the selected text according to the user's instruction:
   - Preserve the original meaning as much as possible
   - Keep formatting intact (Markdown, code blocks, inline code, URLs)
   - If the instruction is unclear, ask for clarification
4. Call `mcp__emacs__interactive-merge-selection` with the rewritten text as the `text` argument.
5. Tell the user: "Ediff is open. Press `b` to apply the change in-place, `q` to quit."

## Notes

- The user provides a rewrite instruction (e.g., "make this more formal", "simplify the language", "add more detail"). Use this instruction to guide the transformation.
- Pressing `b` in Ediff writes the change directly into the user's original buffer.
- Do not edit the file via `Edit`/`Write` — always use `interactive-merge-selection`.