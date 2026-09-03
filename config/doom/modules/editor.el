(global-set-key (kbd "C-M-; C-M-;") 'avy-goto-char)
(global-set-key (kbd "C-M-; ;")     'avy-goto-char)
(global-set-key (kbd "C-M-; C-M-p") 'avy-goto-char-above)
(global-set-key (kbd "C-M-; p")     'avy-goto-char-above)
(global-set-key (kbd "C-M-; C-M-n") 'avy-goto-char-below)
(global-set-key (kbd "C-M-; n")     'avy-goto-char-below)
(global-set-key (kbd "C-M-; C-M-s") 'avy-goto-char-2)
(global-set-key (kbd "C-M-; s")     'avy-goto-char-2)

(global-set-key (kbd "M-g w")   'avy-goto-word-1)
(global-set-key (kbd "M-g e")   'avy-goto-word-0)
(global-set-key (kbd "M-g M-g") 'avy-goto-line)
(global-set-key (kbd "M-g l")   'consult-line)
(global-set-key (kbd "M-g M-l") 'consult-line)

(setq next-line-add-newlines t)
(map! "C-h" #'backward-delete-char-untabify)
(map! "M-g M-q" #'gptel)

(windmove-default-keybindings)

(setq-default fill-column 72)
(setq-default c-basic-offset 4)
(setq lisp-indent-offset 4)
(setq kill-whole-line t)
(setq confirm-kill-emacs nil)
(setq dired-movement-style t)
(setq vterm-timer-delay 0.01)
(setq gc-cons-threshold (* 1024 1024 1024))

(add-to-list 'auto-mode-alist '("\\.puml\\'" . plantuml-mode))
(add-to-list 'auto-mode-alist '("\\.s?vh?\\'" . verilog-ts-mode))
(add-to-list 'auto-mode-alist '("\\.inc\\'" . verilog-ts-mode))
(add-to-list 'auto-mode-alist '("\\.epub\\'" . nov-mode))
(add-to-list 'auto-mode-alist '("\\.f\\'" . conf-space-mode))

(setq org-directory "~/org/")
(setq org-roam-directory "~/org/roam/")

(defun ask-user-about-supersession-threat (fn) "ignore")
(defun ask-user-about-lock (file opponent) "always grab lock" t)

(setq browse-url-browser-function 'eww-browse-url)
(setq eww-search-prefix "https://www.google.com/search?q=")

(add-hook 'xref-backend-functions #'dumb-jump-xref-activate)

(use-package shr-tag-pre-highlight
  :after shr
  :config
  (add-to-list 'shr-external-rendering-functions
               '(pre . shr-tag-pre-highlight)))

(customize-set-variable
 'tramp-ssh-controlmaster-options
 (concat
  "-o ControlPath=/tmp/ssh-ControlPath-%%r@%%h:%%p "
  "-o ControlMaster=auto -o ControlPersist=yes"))

(after! csv-mode
  (add-hook! 'csv-mode-hook
    (csv-align-mode t)
    (csv-header-line t)))
