(defvar lsp-mc/keymap nil "Keymap while lsp-mc is active.")
(unless lsp-mc/keymap
  (setq lsp-mc/keymap (make-sparse-keymap))
  (define-key lsp-mc/keymap (kbd "M-S") 'lsp-mc/mark-all-highlighted)
  )

(require 'dash)
(require 'lsp)
(require 'multiple-cursors)

;;;###autoload
(define-minor-mode lsp-mc-mode "Minor mode for activating multiple cursors on every instance of symbols highlighted by the LSP server"
  nil nil lsp-mc/keymap)

(defun lsp-mc/mark-all-highlighted ()
  (interactive)
  (mc/remove-fake-cursors)
  (let* (
         ;; get all highlighted regions from the LSP server
         (all-highlights (lsp-request "textDocument/documentHighlight"
                                      (lsp--text-document-position-params)))
         (current-point (point))
         ;; convert hash table into regions
         (all-highlight-regions (--map (lsp--range-to-region (gethash "range" it))
                                       all-highlights))
         ;; First element is the regions where the point is enclosed
         ;; Second element is the regions without point enclosed
         (all-regions-separated-by-point-inside (-separate (lambda (region)
                                                             (and (<= (car region) current-point)
                                                                  (< current-point (cdr region))))
                                                           all-highlight-regions))
         (regions-with-point (nth 0 all-regions-separated-by-point-inside))
         ;; There will only ever be one of these
         (region-with-point (car regions-with-point))
         (regions-without-point (nth 1 all-regions-separated-by-point-inside))
         (offset (- current-point
                    (car region-with-point))))
    (mc/save-excursion (--each regions-without-point
                         (let* ((start-of-region (car it))
                                (new-cursor-point (+ start-of-region offset)))
                           (goto-char new-cursor-point)
                           (mc/create-fake-cursor-at-point)
                           (goto-char current-point)))))
  (mc/maybe-multiple-cursors-mode))

;; This command will never run for all cursors, it breaks if so.
(add-to-list 'mc/cmds-to-run-once 'lsp-mc/mark-all-highlighted)

(provide 'lsp-mc)
