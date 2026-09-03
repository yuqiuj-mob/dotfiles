(setq projectile-sort-order 'modification-time)
(setq projectile-tags-command "ctags-exuberant -Re -f \"%s\" %s")

(after! projectile
    (add-to-list 'projectile-globally-ignored-directories "^//.venv$")
    (add-to-list 'projectile-globally-ignored-directories "^//cache$"))

(add-hook 'prog-mode-hook 'highlight-indentation-mode)

(load (expand-file-name "~/.quicklisp/slime-helper.el"))
(setq inferior-lisp-program "sbcl")
