# emacs-mcp-bridge — Roadmap

## Current state (v0.2.0)

- 17 MCP tools (`elisp/emacs-mcp-bridge.el`)
- 5 skills + 4 slash-command aliases
- Works for Claude Code (plugin) and Gemini CLI (extension) from one directory
- Review UX for edits: `ediff-buffers ORIG TEMP` with the original buffer as A — `b` copies a hunk in-place, `q` quits.

## v0.3 — Overlay-based review (next)

Replace the default review UX with gptel-rewrite-style overlays. Ediff stays as an escape hatch for complex multi-hunk cases.

### Motivation

Ediff is modal, hijacks the frame, uses arcane keybindings (`b` to apply, `q` to quit), and silently discards the change if the user quits without pressing `b` — the AI has no way to know. It is overkill for single-region polish/translate edits, which are >90% of real use.

gptel-rewrite (`gptel-rewrite.el` upstream) proves a nicer pattern for single-region edits:

- Overlay on the original region, `display` property shows the proposed text in-situ
- `before-string` shows a status tag (`[MODEL] Ready`)
- Local keymap on the overlay: `C-c C-a` accept, `C-c C-k` reject, `C-c C-e` → ediff (fall-through), `C-c C-d` → unified diff, `C-c C-m` → merge-conflict markers
- Non-modal — user keeps editing elsewhere, comes back when ready
- Multiple overlays can coexist in one buffer (`C-c C-n/p` to navigate)
- Explicit accept/reject eliminates the silent-quit footgun

### Work items

1. **Add `emacs-mcp-bridge-interactive-review-selection` (new tool).**
   - Creates an overlay over the active region.
   - Sets `display` property to the proposed text; sets `face` to a reviewable-highlight face.
   - Attaches a local keymap supporting: accept (`C-c C-a`), reject (`C-c C-k`), escalate-to-ediff (`C-c C-e`), view-diff (`C-c C-d`), merge-markers (`C-c C-m`).
   - Registers the overlay in a buffer-local list so multiple pending reviews coexist.
   - Adopt gptel-rewrite's implementation where license-compatible (MIT-GPL — need to confirm gptel's license before copying code; the *pattern* is free to reimplement).
2. **Make overlay the default for skills.**
   - `emacs-polish`, `emacs-to-cn`, `emacs-to-en` switch to the new tool.
   - Document that ediff remains available via the overlay's `C-c C-e` fall-through, and via `interactive-merge-selection` (unchanged) for explicit callers.
3. **Report user decision back to the AI.**
   - Keep a buffer-local log of accept/reject events keyed by overlay id.
   - Expose `get-last-review-result` as a tool so the AI can check whether the user actually applied the change.
   - Or, simpler: block the tool call until the user acts (accept/reject), mirroring `prompt-user`. Trade-off: blocking is simpler for the AI, but loses the "multiple overlays in flight" benefit. Decision: ship non-blocking + `get-last-review-result`, let skills poll if they care.
4. **Keep `interactive-merge-selection` (ediff-based) in the tool set.**
   - Still useful when the change spans multiple hunks within the region, or when the user explicitly wants side-by-side.
   - Update the skill/README guidance: overlay by default, ediff for large multi-section rewrites.
5. **Update README** — new "Review UX" section with the two modes, when to use which, keybindings table.
6. **Bump to v0.3.0** in `plugin.json` and `gemini-extension.json`.

### Design notes / open questions

- **License of gptel-rewrite.el.** Gptel is GPLv3; we are MIT. Must reimplement from the pattern, not copy the code. The pattern (overlay + display + keymap + status before-string) is not copyrightable.
- **`display` property clobbers selection and point motion through the overlay.** Need to test behavior with `cursor-sensor-mode`, `whitespace-mode`, and when user tries to select inside the overlay. Gptel handles this via `cursor-intangible-mode`; probably steal that.
- **Multi-line display.** The `display` property on an overlay can show arbitrarily many lines. Confirm it re-flows correctly and doesn't break line-number tracking.
- **Font-lock interaction.** The proposed text is raw — it won't be fontified by the major mode unless we propertize it manually. Low priority for prose; higher priority for code. Punt to v0.4.
- **Streaming.** MCP tools are request/response — no native streaming. Gptel's streaming is internal to its request pipeline. We will *not* stream in v0.3. Could revisit if MCP adds streaming tool output.

## Other future work (unscheduled)

- **Project scoping.** Currently the plugin is not project-aware in an isolating sense — all tools operate on `(current-buffer)`, so focus changes between frames leak between projects. Options:
  - Accept "one Emacs daemon per project" as the recommended setup; document it.
  - Add an optional `expected_project_root` arg to write-side tools; tool returns an error if mismatch. Cheap, adds a real safety rail.
  - Add a `require_selection_in_project` skill guideline.
- **Per-hunk overlay (v0.4?).** If the AI returns multi-hunk output (e.g., "polish the whole buffer"), split into N overlays rather than one big one.
- **Font-lock / propertize proposed text** so code rewrites render with the correct major-mode coloring.
- **`undo-tree` / `undo-boundary` hygiene** — ensure overlay accept is a single undo step.
- **Telemetry hook** — optional `emacs-mcp-bridge-post-review-hook` so users can log accept/reject rates.
- **Doom-workspaces awareness** — if persp-mode is loaded, annotate the buffer context with the active workspace name (read-only signal; isolation still requires separate daemons).
- **Headless CI smoke test** — `emacs -Q -batch --eval '(require ...)'` to catch byte-compile and load errors.
