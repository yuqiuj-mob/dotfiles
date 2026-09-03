(load! "modules/ui")
(load! "modules/editor")
(load! "modules/lang-verilog")
(load! "modules/lang-go")
(load! "modules/lang-jinja2")
(load! "modules/org-mode")
(load! "modules/projects")
(load! "modules/tools")

;; Machine/site-local overlay: untracked, lives outside the dotfiles repo.
(setq custom-file (expand-file-name "~/.config/doom-local/custom.el"))
(dolist (f (sort (file-expand-wildcards "~/.config/doom-local/*.el") #'string<))
  (unless (string-suffix-p "custom.el" f)
    (load f nil t)))
;; Load custom-file LAST so Customize/`!`-marked safe local variables persist
;; across reboots (without this, safe-local-variable marks never take effect).
(when (file-exists-p custom-file)
  (load custom-file nil t))
;; deferred body must be self-contained: config.el is not lexically bound
(after! yasnippet
  (let ((snips (expand-file-name "~/.config/doom-local/snippets")))
    (when (file-directory-p snips)
      (add-to-list 'yas-snippet-dirs snips t))))
