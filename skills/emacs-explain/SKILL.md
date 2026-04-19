---
name: emacs-explain
description: Explain the code, prose, symbol, or construct at the cursor or in the active selection in Emacs. Use when the user invokes `/emacs:explain` or asks "what does this do", "explain this", "what is this function", "what's happening here" while focused on something in Emacs. Read-only — does NOT modify the buffer. Requires the `mcp__emacs__*` MCP tools.
version: 0.1.0
license: MIT
---

# Emacs: Explain

Explain whatever the user is pointing at in Emacs — selection, symbol at cursor, or function at cursor. **Read-only:** never call `interactive-merge-*` or `replace-selection`.

## Resolution order for "what am I explaining?"

1. Call `mcp__emacs__get-active-buffer-context` with `include_content: false`. Note the `selection`, `major_mode`, and `line`.
2. **If `selection` is not null →** that's the scope. Explain it.
3. **Else → call `mcp__emacs__get-thing-at-point`** with `thing` picked from the major mode:
   - Programming modes (`*-mode`, `lisp-*`, `python-*`, etc.) → try `"defun"`, then fall back to `"symbol"` if no defun.
   - Prose modes (`markdown-mode`, `org-mode`, `text-mode`) → try `"sentence"`, fall back to `"paragraph"`.
   - If the user said "this word" → use `"word"`; "this line" → `"line"`.
4. **If still nothing →** call `mcp__emacs__message-user` with text like "No thing at point — please select a region first." and stop.

## What makes a good explanation

- **Lead with the one-sentence answer** (what it is, what it does).
- Then add just enough detail for the user to act on it: parameters, invariants, side effects, or surrounding context.
- For symbols defined in the same project: use `mcp__emacs__search-buffer` or `mcp__emacs__describe-symbol` (for elisp) to enrich the explanation.
- For unknown code, **do not hallucinate** — if you can't determine behavior from the visible code, say so and suggest how the user could find out (e.g., "run `M-x describe-function`").
- If a term has well-known context outside the codebase (e.g., a library function, a design pattern), surface that briefly.

## Extra context when needed

- Need the full buffer to understand a symbol? Re-call `get-active-buffer-context` with `include_content: true`.
- Need to see where something is defined? Use `mcp__emacs__search-buffer` with a regex like the symbol name.
- Need docs for an elisp symbol? Use `mcp__emacs__describe-symbol`.

## What NOT to do

- Don't rewrite, refactor, or edit the code — this skill is read-only.
- Don't dump the full buffer into your response.
- Don't explain trivial things at length — a one-line answer beats a paragraph when the code is self-evident.
