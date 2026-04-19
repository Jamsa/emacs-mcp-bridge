;;; emacs-mcp-bridge.el --- MCP tools bridging Emacs with Claude Code / Gemini CLI  -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; Author: Jamsa Zhu
;; Version: 0.2.0
;; Package-Requires: ((emacs "27.1") (mcp-server "0.1.0"))
;; Keywords: tools, ai, mcp
;; URL: https://github.com/jamsa/emacs-mcp-bridge

;; This file is NOT part of GNU Emacs.

;;; Commentary:

;; Registers a curated set of MCP tools that let an MCP-capable AI client
;; (Claude Code, Gemini CLI, etc.) read context from and make edits to the
;; user's Emacs session.  Edits that change content go through Ediff so the
;; user reviews and applies each hunk with `b` — changes write directly to
;; the original buffer in-place.
;;
;; Load from your init file with:
;;
;;     (require 'emacs-mcp-bridge)
;;
;; The `mcp-server' package must already be set up and started so it can
;; serve these tools.  See README for installation of `emacs-mcp-server'.

;;; Code:

(require 'mcp-server)
(require 'mcp-server-tools)

(defgroup emacs-mcp-bridge nil
  "MCP tools exposing Emacs context and edit primitives to AI clients."
  :group 'tools
  :prefix "emacs-mcp-bridge-")

;; ---------------------------------------------------------------------------
;; Helpers
;; ---------------------------------------------------------------------------

(defun emacs-mcp-bridge--project-root ()
  "Return the current project root, or nil."
  (or (and (featurep 'projectile) (projectile-project-root))
      (and (featurep 'project)
           (when-let ((pr (project-current)))
             (project-root pr)))))

(defun emacs-mcp-bridge--ediff-cleanup-hook (&rest bufs)
  "Return a one-shot function that removes itself from `ediff-quit-hook'
and kills each buffer in BUFS that is still live."
  (let (fn)
    (setq fn (lambda ()
               (remove-hook 'ediff-quit-hook fn)
               (dolist (b bufs)
                 (when (buffer-live-p b)
                   (kill-buffer b)))))
    fn))

;; ---------------------------------------------------------------------------
;; 1. get-active-buffer-context
;; ---------------------------------------------------------------------------

(defun emacs-mcp-bridge-get-active-buffer-context (args)
  "Return context of the focused buffer: metadata + selection.
When INCLUDE_CONTENT is true, also include the full buffer content."
  (let* ((include-content (eq (alist-get 'include_content args) t))
         (selection (when (use-region-p)
                     (buffer-substring-no-properties
                      (region-beginning) (region-end))))
         (base `((file_path       . ,(or (buffer-file-name) :null))
                 (buffer_name     . ,(buffer-name))
                 (major_mode      . ,(symbol-name major-mode))
                 (cursor_position . ,(point))
                 (line            . ,(line-number-at-pos))
                 (column          . ,(current-column))
                 (project_root    . ,(or (emacs-mcp-bridge--project-root) :null))
                 (selection       . ,(or selection :null)))))
    (if include-content
        (append base
                `((content . ,(buffer-substring-no-properties
                               (point-min) (point-max)))))
      base)))

(mcp-server-tools-register
 "get-active-buffer-context"
 "Get Active Buffer Context"
 "Returns the focused buffer's metadata (file, mode, cursor, project root) and \
active selection. Pass include_content: true to also return the full buffer \
content — omit it when the selection or metadata alone is enough (saves tokens \
on large files)."
 '((type . "object")
   (properties . ((include_content
                   . ((type . "boolean")
                      (description . "If true, include the full buffer content in the response. Default: false."))))))
 'emacs-mcp-bridge-get-active-buffer-context)

;; ---------------------------------------------------------------------------
;; 2. open-file-at-location
;; ---------------------------------------------------------------------------

(defun emacs-mcp-bridge-open-file-at-location (args)
  "Open FILE_PATH and move cursor to LINE (1-based) and optional COLUMN."
  (let ((file-path (alist-get 'file_path args))
        (line      (alist-get 'line args))
        (column    (alist-get 'column args)))
    (condition-case err
        (progn
          (find-file file-path)
          (goto-char (point-min))
          (forward-line (1- line))
          (when column (move-to-column column))
          (recenter)
          `((status . "success")
            (message . ,(format "Opened %s at %d:%d"
                                file-path line (or column 0)))))
      (error `((status . "error")
               (message . ,(error-message-string err)))))))

(mcp-server-tools-register
 "open-file-at-location"
 "Open File At Location"
 "Opens a file and moves the cursor to a specific line and column."
 '((type . "object")
   (properties . ((file_path . ((type . "string")))
                  (line      . ((type . "integer")))
                  (column    . ((type . "integer")))))
   (required . ("file_path" "line")))
 'emacs-mcp-bridge-open-file-at-location)

;; ---------------------------------------------------------------------------
;; 3. insert-at-point
;; ---------------------------------------------------------------------------

(defun emacs-mcp-bridge-insert-at-point (args)
  "Insert TEXT at the current cursor position."
  (condition-case err
      (progn
        (insert (alist-get 'text args))
        `((status . "success") (message . "Text inserted")))
    (error `((status . "error") (message . ,(error-message-string err))))))

(mcp-server-tools-register
 "insert-at-point"
 "Insert At Point"
 "Inserts text at the current cursor position."
 '((type . "object")
   (properties . ((text . ((type . "string")))))
   (required . ("text")))
 'emacs-mcp-bridge-insert-at-point)

;; ---------------------------------------------------------------------------
;; 4. replace-selection  (direct, no review)
;; ---------------------------------------------------------------------------

(defun emacs-mcp-bridge-replace-selection (args)
  "Replace the active selection with TEXT immediately, no diff review."
  (if (not (use-region-p))
      `((status . "error") (message . "No active selection"))
    (condition-case err
        (progn
          (delete-region (region-beginning) (region-end))
          (insert (alist-get 'text args))
          `((status . "success") (message . "Selection replaced")))
      (error `((status . "error") (message . ,(error-message-string err)))))))

(mcp-server-tools-register
 "replace-selection"
 "Replace Selection"
 "Directly replaces the active selection with the provided text (no diff review)."
 '((type . "object")
   (properties . ((text . ((type . "string")))))
   (required . ("text")))
 'emacs-mcp-bridge-replace-selection)

;; ---------------------------------------------------------------------------
;; 5. interactive-merge-selection
;;
;; Strategy: use the ORIGINAL buffer as Ediff's buffer A and a full-copy
;; temp buffer (with only the selection replaced) as buffer B.  Because A
;; is the real buffer, pressing `b' in Ediff writes the AI change directly
;; in-place.  The two buffers are otherwise identical, so exactly one diff
;; hunk appears.
;; ---------------------------------------------------------------------------

(defun emacs-mcp-bridge-interactive-merge-selection (args)
  "Start an Ediff session between the current buffer (A) and a temp copy
where the active selection is replaced with TEXT (B).  Pressing `b' on the
hunk applies the AI change directly to the original buffer in-place."
  (let ((text (alist-get 'text args)))
    (if (not (use-region-p))
        `((status . "error") (message . "No active selection"))
      (let* ((orig-buf  (current-buffer))
             (sel-start (region-beginning))
             (sel-end   (region-end))
             (prop-buf  (generate-new-buffer
                         (format " *emcp-proposed:%s*" (buffer-name orig-buf)))))
        (with-current-buffer prop-buf
          (insert-buffer-substring orig-buf)
          (goto-char sel-start)
          (delete-region sel-start sel-end)
          (insert text))
        (add-hook 'ediff-quit-hook
                  (emacs-mcp-bridge--ediff-cleanup-hook prop-buf))
        (ediff-buffers orig-buf prop-buf)
        `((status  . "success")
          (message . "Ediff started. 'b' applies the AI change in-place; 'q' quits."))))))

(mcp-server-tools-register
 "interactive-merge-selection"
 "Interactive Merge Selection"
 "Starts an Ediff session: original buffer is A, proposed replacement is B. \
Press 'b' to apply the AI change directly in-place, 'q' to quit."
 '((type . "object")
   (properties . ((text . ((type . "string")))))
   (required . ("text")))
 'emacs-mcp-bridge-interactive-merge-selection)

;; ---------------------------------------------------------------------------
;; 6. interactive-merge-buffer
;; ---------------------------------------------------------------------------

(defun emacs-mcp-bridge-interactive-merge-buffer (args)
  "Ediff BUFFER_NAME (A) against a temp buffer containing NEW_CONTENT (B).
Pressing `b' applies changes directly to the named buffer."
  (let* ((buffer-name (alist-get 'buffer_name args))
         (new-content (alist-get 'new_content args))
         (buf         (get-buffer buffer-name)))
    (if (not buf)
        `((status . "error") (message . "Buffer not found"))
      (let ((prop-buf (generate-new-buffer
                       (format " *emcp-proposed:%s*" buffer-name))))
        (with-current-buffer prop-buf
          (insert new-content))
        (add-hook 'ediff-quit-hook
                  (emacs-mcp-bridge--ediff-cleanup-hook prop-buf))
        (ediff-buffers buf prop-buf)
        `((status  . "success")
          (message . ,(format "Ediff started for buffer '%s'. 'b' applies changes in-place."
                              buffer-name)))))))

(mcp-server-tools-register
 "interactive-merge-buffer"
 "Interactive Merge Buffer"
 "Starts an Ediff session between a named buffer (A) and proposed content (B). \
Press 'b' to apply changes in-place."
 '((type . "object")
   (properties . ((buffer_name . ((type . "string")))
                  (new_content . ((type . "string")))))
   (required . ("buffer_name" "new_content")))
 'emacs-mcp-bridge-interactive-merge-buffer)

;; ---------------------------------------------------------------------------
;; 7. interactive-merge-file
;; ---------------------------------------------------------------------------

(defun emacs-mcp-bridge-interactive-merge-file (args)
  "Open FILE_PATH and Ediff it (A) against a temp buffer with NEW_CONTENT (B).
Pressing `b' applies changes directly to the file buffer."
  (let* ((file-path   (alist-get 'file_path args))
         (new-content (alist-get 'new_content args))
         (buf         (find-file-noselect file-path)))
    (if (not buf)
        `((status . "error") (message . "File not found"))
      (let ((prop-buf (generate-new-buffer
                       (format " *emcp-proposed:%s*"
                               (file-name-nondirectory file-path)))))
        (with-current-buffer prop-buf
          (insert new-content))
        (add-hook 'ediff-quit-hook
                  (emacs-mcp-bridge--ediff-cleanup-hook prop-buf))
        (ediff-buffers buf prop-buf)
        `((status  . "success")
          (message . ,(format "Ediff started for '%s'. 'b' applies changes in-place."
                              file-path)))))))

(mcp-server-tools-register
 "interactive-merge-file"
 "Interactive Merge File"
 "Opens a file and starts an Ediff session against proposed new content. \
Press 'b' to apply changes in-place."
 '((type . "object")
   (properties . ((file_path   . ((type . "string")))
                  (new_content . ((type . "string")))))
   (required . ("file_path" "new_content")))
 'emacs-mcp-bridge-interactive-merge-file)

;; ---------------------------------------------------------------------------
;; 8. list-buffers
;; ---------------------------------------------------------------------------

(defun emacs-mcp-bridge-list-buffers (_)
  "List all open buffers with their file paths and major modes."
  `((buffers . ,(mapcar (lambda (buf)
                          `((name       . ,(buffer-name buf))
                            (file_path  . ,(or (buffer-file-name buf) :null))
                            (major_mode . ,(symbol-name
                                            (buffer-local-value 'major-mode buf)))))
                        (buffer-list)))))

(mcp-server-tools-register
 "list-buffers"
 "List Buffers"
 "Lists all open buffers with their file paths and major modes."
 '((type . "object"))
 'emacs-mcp-bridge-list-buffers)

;; ---------------------------------------------------------------------------
;; 9. switch-to-buffer
;; ---------------------------------------------------------------------------

(defun emacs-mcp-bridge-switch-to-buffer (args)
  "Switch to buffer named BUFFER_NAME."
  (let ((name (alist-get 'buffer_name args)))
    (if (get-buffer name)
        (progn
          (switch-to-buffer name)
          `((status . "success")
            (message . ,(format "Switched to buffer '%s'" name))))
      `((status . "error") (message . "Buffer not found")))))

(mcp-server-tools-register
 "switch-to-buffer"
 "Switch To Buffer"
 "Switches to a buffer by name."
 '((type . "object")
   (properties . ((buffer_name . ((type . "string")))))
   (required . ("buffer_name")))
 'emacs-mcp-bridge-switch-to-buffer)

;; ---------------------------------------------------------------------------
;; 10. get-project-root
;; ---------------------------------------------------------------------------

(defun emacs-mcp-bridge-get-project-root (_)
  "Return the root directory of the current project."
  `((project_root . ,(or (emacs-mcp-bridge--project-root)
                          default-directory))))

(mcp-server-tools-register
 "get-project-root"
 "Get Project Root"
 "Returns the root directory of the current project."
 '((type . "object"))
 'emacs-mcp-bridge-get-project-root)

;; ---------------------------------------------------------------------------
;; 11. list-files-in-project
;; ---------------------------------------------------------------------------

(defun emacs-mcp-bridge-list-files-in-project (_)
  "List all tracked files in the current project."
  (let ((files (cond ((and (featurep 'projectile) (projectile-project-p))
                      (projectile-current-project-files))
                     ((and (featurep 'project) (project-current))
                      (project-files (project-current)))
                     (t nil))))
    (if files
        `((files . ,files))
      `((status . "error") (message . "Not in a project")))))

(mcp-server-tools-register
 "list-files-in-project"
 "List Files In Project"
 "Lists all tracked files in the current project."
 '((type . "object"))
 'emacs-mcp-bridge-list-files-in-project)

;; ---------------------------------------------------------------------------
;; 12. describe-symbol
;; ---------------------------------------------------------------------------

(defun emacs-mcp-bridge-describe-symbol (args)
  "Return documentation for elisp SYMBOL."
  (let* ((sym-name (alist-get 'symbol args))
         (sym      (intern-soft sym-name)))
    (if (not sym)
        `((status . "error") (message . "Symbol not found"))
      `((status        . "success")
        (symbol        . ,sym-name)
        (documentation . ,(or (ignore-errors (documentation sym))
                               (ignore-errors
                                 (documentation-property
                                  sym 'variable-documentation))
                               "No documentation available"))))))

(mcp-server-tools-register
 "describe-symbol"
 "Describe Symbol"
 "Returns documentation for an Emacs Lisp symbol (function or variable)."
 '((type . "object")
   (properties . ((symbol . ((type . "string")))))
   (required . ("symbol")))
 'emacs-mcp-bridge-describe-symbol)

;; ---------------------------------------------------------------------------
;; 13. search-buffer
;; ---------------------------------------------------------------------------

(defun emacs-mcp-bridge-search-buffer (args)
  "Search QUERY (regex) in the current buffer; return matching lines."
  (let (results)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward (alist-get 'query args) nil t)
        (push `((line    . ,(line-number-at-pos))
                (content . ,(string-trim (thing-at-point 'line t))))
              results)))
    `((results . ,(nreverse results)))))

(mcp-server-tools-register
 "search-buffer"
 "Search Buffer"
 "Searches for a regex pattern in the current buffer and returns matching lines."
 '((type . "object")
   (properties . ((query . ((type . "string")))))
   (required . ("query")))
 'emacs-mcp-bridge-search-buffer)

;; ---------------------------------------------------------------------------
;; 14. recent-files
;; ---------------------------------------------------------------------------

(defun emacs-mcp-bridge-recent-files (_)
  "Return the list of recently opened files."
  `((recent_files . ,(or (and (boundp 'recentf-list) recentf-list) '()))))

(mcp-server-tools-register
 "recent-files"
 "Recent Files"
 "Returns the list of recently opened files."
 '((type . "object"))
 'emacs-mcp-bridge-recent-files)

;; ---------------------------------------------------------------------------
;; 15. get-thing-at-point
;; ---------------------------------------------------------------------------

(defconst emacs-mcp-bridge--thing-at-point-kinds
  '("symbol" "word" "sexp" "defun" "line" "sentence" "paragraph" "filename" "url")
  "Thing kinds that `emacs-mcp-bridge-get-thing-at-point' accepts.")

(defun emacs-mcp-bridge-get-thing-at-point (args)
  "Return the \"thing\" (word, sexp, defun, etc.) at point, plus its bounds.

ARGS is an alist with:
  thing — one of the strings in
          `emacs-mcp-bridge--thing-at-point-kinds'; defaults to \"symbol\"."
  (let* ((kind-str (or (alist-get 'thing args) "symbol"))
         (kind (intern kind-str)))
    (if (not (member kind-str emacs-mcp-bridge--thing-at-point-kinds))
        `((status . "error")
          (message . ,(format "Unknown thing kind '%s'. Valid: %s"
                              kind-str
                              (mapconcat #'identity
                                         emacs-mcp-bridge--thing-at-point-kinds
                                         ", "))))
      (let* ((bounds (bounds-of-thing-at-point kind))
             (text   (and bounds
                          (buffer-substring-no-properties
                           (car bounds) (cdr bounds)))))
        (if (not bounds)
            `((status . "no_thing")
              (message . ,(format "No %s at point" kind-str)))
          `((status . "success")
            (thing  . ,kind-str)
            (text   . ,text)
            (start  . ,(car bounds))
            (end    . ,(cdr bounds))
            (line   . ,(line-number-at-pos (car bounds)))))))))

(mcp-server-tools-register
 "get-thing-at-point"
 "Get Thing At Point"
 "Returns the word, symbol, sexp, defun, line, sentence, paragraph, filename, \
or URL at the cursor, together with its character bounds. Useful when the user \
points at something but hasn't selected it — avoids asking them to select first."
 '((type . "object")
   (properties . ((thing
                   . ((type . "string")
                      (description . "What to grab: symbol, word, sexp, defun, line, sentence, paragraph, filename, url. Default: symbol.")
                      (enum . ("symbol" "word" "sexp" "defun"
                               "line" "sentence" "paragraph"
                               "filename" "url")))))))
 'emacs-mcp-bridge-get-thing-at-point)

;; ---------------------------------------------------------------------------
;; 16. prompt-user
;; ---------------------------------------------------------------------------

(defun emacs-mcp-bridge-prompt-user (args)
  "Ask the user a question in the Emacs minibuffer and return their answer.

ARGS:
  prompt  — question text (required).
  choices — optional list of strings; if given, the user picks one
            via `completing-read'.  Otherwise, free-form input via `read-string'.
  default — optional default answer.

Blocks until the user responds."
  (let* ((prompt  (alist-get 'prompt args))
         (choices (alist-get 'choices args))
         (default (alist-get 'default args))
         (label   (if default
                      (format "%s (default %s): " prompt default)
                    (format "%s: " prompt)))
         (answer  (cond
                   ((and choices (> (length choices) 0))
                    (completing-read label (append choices nil)
                                     nil t nil nil default))
                   (t
                    (read-string label nil nil default)))))
    `((status . "success") (answer . ,answer))))

(mcp-server-tools-register
 "prompt-user"
 "Prompt User"
 "Asks the user a question via the Emacs minibuffer and returns their answer. \
Supports free-form input or a list of choices. Blocks until the user responds. \
Use this to confirm actions, disambiguate intent, or collect a missing value \
instead of guessing."
 '((type . "object")
   (properties . ((prompt  . ((type . "string")
                              (description . "The question to show the user.")))
                  (choices . ((type . "array")
                              (items . ((type . "string")))
                              (description . "If provided, the user picks one of these options.")))
                  (default . ((type . "string")
                              (description . "Optional default answer.")))))
   (required . ("prompt")))
 'emacs-mcp-bridge-prompt-user)

;; ---------------------------------------------------------------------------
;; 17. message-user
;; ---------------------------------------------------------------------------

(defun emacs-mcp-bridge-message-user (args)
  "Display TEXT as a one-line message in the Emacs echo area."
  (let ((text (alist-get 'text args)))
    (message "%s" text)
    `((status . "success") (displayed . ,text))))

(mcp-server-tools-register
 "message-user"
 "Message User"
 "Displays a one-line message in the Emacs echo area (minibuffer). Use for \
lightweight status updates (\"applied 3 fixes\") without adding noise to the \
chat transcript. Does not block."
 '((type . "object")
   (properties . ((text . ((type . "string")
                           (description . "The message text to display.")))))
   (required . ("text")))
 'emacs-mcp-bridge-message-user)

(message "emacs-mcp-bridge: 17 MCP tools registered")

(provide 'emacs-mcp-bridge)
;;; emacs-mcp-bridge.el ends here
