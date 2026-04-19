---
name: emacs-integration
description: Protocol for collaborating with the user's live Emacs session via MCP. Use this skill whenever the `mcp__emacs__*` tools are available — it applies to every editing, research, or navigation task while Emacs is the user's active environment. Covers context-first reads, interactive merging, synchronized views, diagnostics, and project intelligence tools.
version: 0.1.0
license: MIT
---

# Emacs Integration Protocol

Apply this protocol for every task while the `mcp__emacs__*` tools are available. It keeps edits reviewable, keeps the user's view in sync, and prefers Emacs-native introspection over blind filesystem searches.

## 1. Context-First

Call `mcp__emacs__get-active-buffer-context` at the start of the task (or whenever the user's focus might have shifted). It returns metadata plus the active selection.

**Token hygiene:** the tool omits the full buffer content by default. Pass `include_content: true` only when you actually need to read the whole file — otherwise you waste tokens on every call.

An active `selection` is **high-priority scope** — treat it as the user's explicit focus area.

If the user is pointing at something but hasn't selected it, call `mcp__emacs__get-thing-at-point` with a `thing` like `symbol`, `defun`, or `sentence`. This avoids asking them to select first.

## 2. Interactive Merging

When proposing code or text changes, **prefer these tools** over `Edit`/`Write`:

- `mcp__emacs__interactive-merge-selection` — for changes scoped to the active selection
- `mcp__emacs__interactive-merge-buffer` — for changes to an open buffer as a whole
- `mcp__emacs__interactive-merge-file` — for changes to a file on disk

All three open Ediff. Pressing `b` on a hunk **applies the AI change in-place** to the original buffer/file. Pressing `q` quits.

Tell the user which keys to press when you start a merge.

For trivial, unambiguous swaps where review is unnecessary, `mcp__emacs__replace-selection` writes directly with no diff.

## 3. Synchronized View

After changes land, call `mcp__emacs__open-file-at-location` to move the user's Emacs view to the relevant line so they don't have to hunt for it.

## 4. Project Intelligence

Prefer these MCP tools over raw filesystem searches when the user is in a project:

- `mcp__emacs__get-project-root`
- `mcp__emacs__list-files-in-project`
- `mcp__emacs__search-buffer` (regex search in current buffer)
- `mcp__emacs__describe-symbol` (elisp docs)

## 5. Diagnostics Loop

If Flycheck or Flymake are configured, check for errors after edits via `mcp__emacs__get-diagnostics` (provided by the base MCP server).

## 5a. Close the Dialog Loop

Don't guess when you can ask. For ambiguous intent, missing values, or confirming a non-trivial action, call `mcp__emacs__prompt-user` with a question (and an optional `choices` array). It blocks on a minibuffer prompt and returns the user's answer.

For lightweight "done" or "status" notifications that don't belong in chat, call `mcp__emacs__message-user` — shows in the echo area, no chat noise.

## 6. Elisp Introspection

For unfamiliar elisp, use `mcp__emacs__describe-symbol` first. If you need to execute elisp ad-hoc, prefix any temporary helper functions with `my/mcp_tmp/<name>` so the user can clearly identify and clean them up.

## 7. No Blind Edits

If the user has a selection active and asks a broad question, assume the selection is the scope unless they say otherwise. Ask before operating outside it.
