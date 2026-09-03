(after! python
  (when (executable-find "ipython")
    (setq python-shell-interpreter "ipython"
          python-shell-interpreter-args "-i --simple-prompt")))

(use-package! comint-mime
  :hook (inferior-python-mode . comint-mime-setup))
