(setq chatgpt-shell-openai-key
      (lambda () (nth 0 (process-lines "pass" "show" "API/openai"))))
(setq dall-e-shell-openai-key
      (lambda () (nth 0 (process-lines "pass" "show" "API/openai"))))
(setq chatgpt-shell-google-key
      (lambda () (nth 0 (process-lines "pass" "show" "API/gemini"))))
(setq chatgpt-shell-anthropic-key
      (lambda () (nth 0 (process-lines "pass" "show" "API/anthropic"))))
(setq chatgpt-shell-openrouter-key
      (lambda () (nth 0 (process-lines "pass" "show" "API/openrouter"))))

(setq org-ai-openai-api-token
      (lambda () (nth 0 (process-lines "pass" "show" "API/openai"))))
(use-package! org-ai
    :config (org-ai-global-mode))

(use-package! gptel
 :config
 ;; Set Claude as the default backend and model
 (setq gptel-backend
       (gptel-make-anthropic "Claude"
         :stream t
         :key (lambda () (nth 0 (process-lines "pass" "show" "API/anthropic")))))
 (setq gptel-model 'claude-sonnet-4-20250514)

 ;; Keep OpenAI available as an alternative (switch via C-c g then M-x gptel-menu)
 (setq gptel-api-key (lambda () (nth 0 (process-lines "pass" "show" "API/openai")))))

(defvar gptel-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "g")       #'gptel)
    (define-key map (kbd "C-c RET") #'gptel-send)
    (define-key map (kbd "C-c C-c") #'gptel-send)
    (define-key map (kbd "C-c C-k") #'gptel-abort)
    (define-key map (kbd "C-c C-r") #'gptel-rewrite-menu)
    (define-key map (kbd "C-c C-i") #'gptel-add-context)
    (define-key map (kbd "C-c C-f") #'gptel-add-file)
    (define-key map (kbd "C-c C-n") #'gptel-next-history)
    (define-key map (kbd "C-c C-p") #'gptel-previous-history)
    map)
  "Keymap for gptel mode.")

(map! "C-c g" gptel-mode-map)
(setq gptel-default-mode 'org-mode)

(use-package! claude-code-ide
  :bind ("C-c C-'" . claude-code-ide-menu)
  :config
  (setq claude-code-ide-terminal-backend 'eat)
  (claude-code-ide-emacs-tools-setup))

(use-package! copilot
  :bind (:map copilot-completion-map
              ("<tab>"  . 'copilot-accept-completion)
              ("TAB"    . 'copilot-accept-completion)
              ("C-TAB"  . 'copilot-accept-completion-by-word)
              ("C-<tab>" . 'copilot-accept-completion-by-word)))

(defun copilot-change-activation ()
  "Cycle copilot: automatic -> manual -> off."
  (interactive)
  (if (and copilot-mode copilot-manual-mode)
      (progn
        (message "deactivating copilot")
        (global-copilot-mode -1)
        (setq copilot-manual-mode nil))
    (if copilot-mode
        (progn
          (message "activating copilot manual mode")
          (setq copilot-manual-mode t))
      (message "activating copilot mode"))))

(define-key global-map (kbd "M-C-<escape>") #'copilot-change-activation)

(add-hook 'gdb-mode-hook   (lambda () (when (boundp 'tool-bar-mode) (tool-bar-mode 1))))
(add-hook 'gdb-exited-hook (lambda () (when (boundp 'tool-bar-mode) (tool-bar-mode -1))))

(setq plantuml-output-type "png")
(setq plantuml-default-exec-mode 'jar)

(setq wavedrom-output-format "png")
(setq wavedrom-output-directory "~/wavedrom")

(setq ob-mermaid-cli-path "/usr/bin/mmdc")
(use-package! mermaid-mode)

(use-package! youtube-sub-extractor
  :commands (youtube-sub-extractor-extract-subs)
  :config
  (map! :map youtube-sub-extractor-subtitles-mode-map
    :desc "copy timestamp URL"  :n "RET"     #'youtube-sub-extractor-copy-ts-link
    :desc "browse at timestamp" :n "C-c C-o" #'youtube-sub-extractor-browse-ts-link))
(setq youtube-sub-extractor-timestamps 'left-margin)

(setq notmuch-fcc-dirs "Sent +sent -inbox -unread")

(defun rj/--current-buffer-or-dired-path ()
  "Return the path the current buffer represents, or signal an error."
  (or (buffer-file-name)
      (and (derived-mode-p 'dired-mode) (directory-file-name default-directory))
      (user-error "Buffer is not visiting a file")))

(defun rj/--push-to-clipboards (s)
  "Push string S to the Emacs kill-ring and the Windows clipboard via clip.exe."
  (kill-new s)
  (when (executable-find "clip.exe")
    (with-temp-buffer
      (insert s)
      (call-process-region (point-min) (point-max) "clip.exe")))
  (message "Copied: %s" s))

(defun rj/--path-to-windows (path)
  "Convert PATH (a Linux/WSL path) to a Windows-native backslash path."
  (let ((p (expand-file-name path)))
    (cond
     ((string-match "\\`/mnt/\\([a-zA-Z]\\)/\\(.*\\)" p)
      (concat (upcase (match-string 1 p))
              ":\\"
              (replace-regexp-in-string "/" "\\\\" (match-string 2 p))))
     (t
      (concat "\\\\wsl.localhost\\Dev"
              (replace-regexp-in-string "/" "\\\\" p))))))

(defun rj/--path-to-wsl-url (path)
  "Convert PATH (a Linux/WSL path) to a file:// URL openable in Windows browsers."
  (let* ((p (expand-file-name path))
         (encode (lambda (s)
                   (replace-regexp-in-string
                    "[ #?%]"
                    (lambda (c) (format "%%%02X" (string-to-char c)))
                    s t t))))
    (cond
     ((string-match "\\`/mnt/\\([a-zA-Z]\\)/\\(.*\\)" p)
      (concat "file:///"
              (upcase (match-string 1 p))
              ":/"
              (funcall encode (match-string 2 p))))
     (t
      (concat "file://///wsl$/Dev" (funcall encode p))))))

;; Buffer-acting commands (no args, derive path from current buffer).
(defun rj/copy-buffer-as-windows ()
  "Copy the current buffer's file path as a Windows-native path."
  (interactive)
  (rj/--push-to-clipboards (rj/--path-to-windows (rj/--current-buffer-or-dired-path))))

(defun rj/copy-buffer-as-wsl-url ()
  "Copy the current buffer's file path as a file:// URL."
  (interactive)
  (rj/--push-to-clipboards (rj/--path-to-wsl-url (rj/--current-buffer-or-dired-path))))

;; File-acting commands (take a path argument; embark injects the candidate
;; via the standard `f' interactive prompt, which embark intercepts).
(defun rj/copy-file-as-windows (path)
  "Copy PATH as a Windows-native path. Designed as an embark action.
When invoked outside embark (e.g. `M-x'), prompts for a file."
  (interactive "fFile: ")
  (rj/--push-to-clipboards (rj/--path-to-windows path)))

(defun rj/copy-file-as-wsl-url (path)
  "Copy PATH as a file:// URL. Designed as an embark action.
When invoked outside embark (e.g. `M-x'), prompts for a file."
  (interactive "fFile: ")
  (rj/--push-to-clipboards (rj/--path-to-wsl-url path)))

;; Backward-compatible aliases for old names so muscle memory still works.
(defalias 'rj/copy-buffer-path-as-windows #'rj/copy-buffer-as-windows)
(defalias 'rj/copy-buffer-path-as-wsl-url #'rj/copy-buffer-as-wsl-url)
(defalias 'rj/copy-as-windows             #'rj/copy-buffer-as-windows)
(defalias 'rj/copy-as-wsl-url             #'rj/copy-buffer-as-wsl-url)

(define-key global-map (kbd "C-<f12>") #'rj/copy-buffer-as-wsl-url)

(after! embark
  (define-key embark-file-map (kbd "W") #'rj/copy-file-as-windows)
  (define-key embark-file-map (kbd "U") #'rj/copy-file-as-wsl-url))

(use-package! p4)

(use-package! nov
  :mode ("\\.epub\\'" . nov-mode)
  :config
  (setq nov-text-width 80)
  (add-hook 'nov-mode-hook
            (lambda ()
              (face-remap-add-relative 'variable-pitch :height 1.15)
              (variable-pitch-mode 1))))

(use-package! hjson-mode
  :mode "\\.hjson\\'")
