# Emacs Integration Protocol

This extension exposes MCP tools that let you collaborate with the user's live Emacs session. Apply this protocol for every task while the `mcp__emacs__*` tools are available.

## 1. Context-First

Call `mcp__emacs__get-active-buffer-context` at the start of the task (or whenever the user's focus might have shifted). It returns metadata plus the active selection.

**Token hygiene:** the tool omits the full buffer content by default. Pass `include_content: true` only when you actually need to read the whole file.

An active `selection` is **high-priority scope** — treat it as the user's explicit focus area.

If the user is pointing at something but hasn't selected it, call `mcp__emacs__get-thing-at-point` with a `thing` like `symbol`, `defun`, or `sentence`. This avoids asking them to select first.

## 2. Interactive Merging

When proposing code or text changes, **prefer these tools** over direct file writes:

- `mcp__emacs__interactive-merge-selection` — for changes scoped to the active selection
- `mcp__emacs__interactive-merge-buffer` — for changes to an open buffer as a whole
- `mcp__emacs__interactive-merge-file` — for changes to a file on disk

All three open Ediff. Pressing `b` on a hunk applies the AI change in-place to the original buffer/file. Pressing `q` quits. Tell the user which keys to press when you start a merge.

For trivial, unambiguous swaps where review is unnecessary, `mcp__emacs__replace-selection` writes directly with no diff.

## 3. Synchronized View

After changes land, call `mcp__emacs__open-file-at-location` to move the user's Emacs view to the relevant line.

## 4. Project Intelligence

Prefer these MCP tools over raw filesystem searches when the user is in a project:

- `mcp__emacs__get-project-root`
- `mcp__emacs__list-files-in-project`
- `mcp__emacs__search-buffer` (regex search in current buffer)
- `mcp__emacs__describe-symbol` (elisp docs)

## 5. Close the Dialog Loop

Don't guess when you can ask. For ambiguous intent or missing values, call `mcp__emacs__prompt-user` (free-form or `choices` array; blocks until the user answers). For lightweight status updates, call `mcp__emacs__message-user` — shows in the echo area, no chat noise.

## 6. No Blind Edits

If the user has a selection active and asks a broad question, assume the selection is the scope unless they say otherwise. Ask before operating outside it.
