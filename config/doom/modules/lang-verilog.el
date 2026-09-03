(use-package! verilog-ts-mode
    :config
    (setq verilog-ts-indent-level 3)
    (setq verilog-auto-newline nil))

(after! verilog-ts-mode
  ;; Drop the earlier globally-scoped advice (renamed since) so a config
  ;; reload doesn't stack it on the scoped one and double the instance name.
  (advice-remove 'verilog-ts--node-identifier-name
                 'verilog-ts--node-identifier-name@verilog-ts-imenu-instance-name)

  (defvar my/verilog-ts-imenu-active nil
    "Non-nil while `verilog-ts' imenu index is being built.")

  (defvar my/verilog-ts-imenu-instance-width 22
    "Column width the instance name is padded to in imenu labels.")

  ;; Preserve text properties (faces) on labels; the stock formatter uses
  ;; (format "%s" name), which strips them.
  (setq verilog-ts-imenu-format-item-label-function
        (lambda (_type name) name))

  (define-advice verilog-ts--imenu-create-index
      (:around (orig-fn &rest args) my/verilog-ts-imenu-flag)
    (let ((my/verilog-ts-imenu-active t))
      (apply orig-fn args)))

  (define-advice verilog-ts--node-identifier-name
      (:around (orig-fn node) my/verilog-ts-imenu-instance-name)
    (let ((name (funcall orig-fn node)))
      (if (and my/verilog-ts-imenu-active
               node
               (string-match verilog-ts-instance-re (treesit-node-type node)))
          (let ((inst (ignore-errors (verilog-ts--node-instance-name node))))
            (if (and inst (not (string-empty-p inst)))
                (concat
                 (propertize (format (format "%%-%ds" my/verilog-ts-imenu-instance-width) inst)
                             'face 'font-lock-function-name-face)
                 (propertize name 'face 'shadow))
              name))
        name))))

(use-package! verilog-ext
  :hook
    (verilog-ts-mode . verilog-ext-mode)
    (verilog-ext-mode . which-function-mode)
    ;; (verilog-ext-mode . lsp-deferred)  ;; disabled: start manually with M-x lsp
  :init
  (setq verilog-ext-feature-list
        '(xref capf hierarchy lsp flycheck beautify
          navigation template formatter compilation
          imenu which-func typedefs block-end-comments ports))


  :config
    (set-face-attribute 'verilog-ts-font-lock-grouping-keywords-face nil :foreground "dark orange")
    (set-face-attribute 'verilog-ts-font-lock-punctuation-face nil       :foreground "burlywood")
    (set-face-attribute 'verilog-ts-font-lock-operator-face nil          :foreground "burlywood" :weight 'extra-bold)
    (set-face-attribute 'verilog-ts-font-lock-brackets-face nil          :foreground "goldenrod")
    (set-face-attribute 'verilog-ts-font-lock-parenthesis-face nil       :foreground "dark goldenrod")
    (set-face-attribute 'verilog-ts-font-lock-curly-braces-face nil      :foreground "DarkGoldenrod2")
    (set-face-attribute 'verilog-ts-font-lock-port-connection-face nil   :foreground "bisque2")
    (set-face-attribute 'verilog-ts-font-lock-dot-name-face nil          :foreground "gray70")
    (set-face-attribute 'verilog-ts-font-lock-brackets-content-face nil  :foreground "yellow green")
    (set-face-attribute 'verilog-ts-font-lock-width-num-face nil         :foreground "chartreuse2")
    (set-face-attribute 'verilog-ts-font-lock-width-type-face nil        :foreground "sea green" :weight 'bold)
    (set-face-attribute 'verilog-ts-font-lock-module-face nil            :foreground "green1")
    (set-face-attribute 'verilog-ts-font-lock-instance-face nil          :foreground "medium spring green")
    (set-face-attribute 'verilog-ts-font-lock-time-event-face nil        :foreground "deep sky blue" :weight 'bold)
    (set-face-attribute 'verilog-ts-font-lock-time-unit-face nil         :foreground "light steel blue")
    (set-face-attribute 'verilog-ts-font-lock-preprocessor-face nil      :foreground "pale goldenrod")
    (set-face-attribute 'verilog-ts-font-lock-modport-face nil           :foreground "light blue")
    (set-face-attribute 'verilog-ts-font-lock-direction-face nil         :foreground "RosyBrown3")
    (set-face-attribute 'verilog-ts-font-lock-translate-off-face nil     :background "gray20" :slant 'italic)
    (set-face-attribute 'verilog-ts-font-lock-attribute-face nil         :foreground "orange1")

    (setq verilog-ext-flycheck-linter 'verilog-verible)
    (setq verilog-ext-tags-backend 'tree-sitter)
    (setq flycheck-checker-error-threshold 1000)
    (setq verilog-ext-formatter-indentation-spaces 3)

    (verilog-ext-mode-setup))

(after! lsp-mode
  ;; Use verible (built-in lsp-mode client) — disable everything else
  (dolist (mode '(verilog-mode verilog-ts-mode))
    (setq lsp-disabled-clients (assq-delete-all mode lsp-disabled-clients))
    (push (cons mode '(svlangserver lsp-verilog
                       ve-hdl-checker ve-svlangserver ve-svls ve-veridian))
          lsp-disabled-clients)))

(defun verilog-insert-cust-comment-block ()
  "Insert a section comment block and position cursor inside."
  (interactive)
  (insert
   " /* ------------------------------------------------------------------\n"
   "  * \n"
   "  * ------------------------------------------------------------------ */\n")
  (forward-line -1)
  (indent-region (line-beginning-position) (line-end-position))
  (forward-line -1)
  (indent-region (line-beginning-position) (line-end-position)))

(defun highlight-uvmlog ()
  "Highlight UVM severity keywords in current buffer."
  (interactive)
  (font-lock-add-keywords
   nil
   '(("UVM_WARNING" . 'font-lock-function-name-face)
     ("UVM_INFO"    . 'font-lock-string-face)
     ("UVM_ERROR"   . 'font-lock-warning-face)
     ("UVM_FATAL"   . 'font-lock-warning-face))))

(defvar my/verilog-flist-skipped nil
  "Lines skipped by the last `my/parse-verilog-flist' run (missing/unresolved).")

(defvar my/verilog-flist--dir-cache nil
  "Dir -> truename memo for `my/parse-verilog-flist' (truename is the hot spot).")

(defun my/parse-verilog-flist (file &optional seen)
  "Recursively parse Verilog .f filelist FILE, return absolute source files.
SEEN is an internal hash table used to dedupe across nested filelists."
  (let* ((top (null seen))
         (seen (or seen (make-hash-table :test #'equal)))
         (dir (file-name-directory (file-truename file)))
         files)
    (when top
      (setq my/verilog-flist-skipped nil
            my/verilog-flist--dir-cache (make-hash-table :test #'equal)))
    (cl-flet* ((unresolved-p (s) (and (string-match "\\${?\\([A-Za-z_][A-Za-z0-9_]*\\)}?" s)
                                       (not (getenv (match-string 1 s)))))
               (abs (p) (let* ((p (expand-file-name (substitute-env-vars p t) dir))
                               (d (file-name-directory p)))
                          (unless my/verilog-flist--dir-cache
                            (setq my/verilog-flist--dir-cache (make-hash-table :test #'equal)))
                          (concat (or (gethash d my/verilog-flist--dir-cache)
                                      (puthash d (file-name-as-directory (file-truename d))
                                               my/verilog-flist--dir-cache))
                                  (file-name-nondirectory p))))
               (skip (why s) (push (format "%s: %s (%s)" (file-name-nondirectory file) s why)
                                   my/verilog-flist-skipped))
               (add (p) (unless (gethash p seen)
                          (puthash p t seen)
                          (push p files))))
      (with-temp-buffer
        (insert-file-contents file)
        (goto-char (point-min))
        (while (not (eobp))
          (let ((line (string-trim
                       (replace-regexp-in-string "\\(//\\|#\\).*" ""
                        (buffer-substring-no-properties (line-beginning-position) (line-end-position))))))
            (cond
             ((string-empty-p line))
             ((unresolved-p line) (skip "unresolved env var" line))
             ((string-match "^-[fF][ \t]+\\(.+\\)$" line)
              (let ((f (abs (match-string 1 line))))
                (if (file-regular-p f)
                    (setq files (append (nreverse (my/parse-verilog-flist f seen)) files))
                  (skip "missing filelist" line))))
             ((string-match "^-y[ \t]+\\(.+\\)$" line)
              (let ((d (abs (match-string 1 line))))
                (if (file-directory-p d)
                    (mapc #'add (directory-files d t "\\.s?vh?\\'"))
                  (skip "missing libdir" line))))
             ((string-match "^-v[ \t]+\\(.+\\)$" line)
              (let ((f (abs (match-string 1 line))))
                (if (file-regular-p f) (add f) (skip "missing file" line))))
             ((string-match "^[-+]" line))  ; +incdir+, +define+, -timescale, ...
             (t (let ((f (abs line)))
                  (if (file-regular-p f) (add f) (skip "missing file" line))))))
          (forward-line 1))))
    (when (and top my/verilog-flist-skipped)
      (message "verilog flist: skipped %d line(s), see `my/verilog-flist-skipped'"
               (length my/verilog-flist-skipped)))
    (nreverse files)))

(defun my/verilog-ext-flist-project (name root &rest flists)
  "Build a `verilog-ext-project-alist' entry NAME rooted at ROOT from FLISTS.
FLISTS are relative to ROOT. Returns nil if ROOT does not exist."
  (when (file-directory-p root)
    (setq my/verilog-flist-skipped nil
          my/verilog-flist--dir-cache nil)
    (let ((seen (make-hash-table :test #'equal)))
      (list name
            :root root
            :files (apply #'append
                          (mapcar (lambda (f) (my/parse-verilog-flist (expand-file-name f root) seen))
                                  flists))))))

(map! :after verilog-ext
      :map verilog-ext-mode-map
      :localleader
      "h" #'verilog-ext-hierarchy-current-buffer
      "u" #'verilog-ext-tags-get-async)
