(after! prog-mode
    (add-hook 'org-mode-hook
          (lambda () (add-hook 'after-save-hook #'org-babel-tangle
                          :append :local))))

(remove-hook 'org-mode-hook #'org-indent-mode)

(dolist (face '(window-divider
                window-divider-first-pixel
                window-divider-last-pixel))
  (face-spec-reset-face face)
  (set-face-foreground face (face-attribute 'default :background)))
(set-face-background 'fringe (face-attribute 'default :background))

(setq
 org-auto-align-tags nil
 org-tags-column 0
 org-catch-invisible-edits 'show-and-error
 org-special-ctrl-a/e t
 org-insert-heading-respect-content t
 org-hide-emphasis-markers t
 org-pretty-entities t
 org-agenda-tags-column 0)

(use-package! org-modern
  :config
    (global-org-modern-mode))

(use-package! org-modern-indent
  :after org-modern
  :hook (org-mode . org-modern-indent-mode))

(defun load-org-agenda ()
  (interactive)
  (setq org-agenda-files
    (append
        (file-expand-wildcards "~/org/roam/boards/*.org")
        (file-expand-wildcards "~/org/roam/daily/*.org"))))

(after! org
    (load-org-agenda))

(with-eval-after-load 'ox-latex
  (defun org-latex-ref-to-cref (text backend info)
    "Use \\cref instead of \\ref in latex export."
    (when (org-export-derived-backend-p backend 'latex)
      (replace-regexp-in-string "\\\\ref{" "\\\\cref{" text)))
  (add-to-list 'org-export-filter-final-output-functions
               'org-latex-ref-to-cref))

(setq org-export-with-broken-links t)

;; Allow orgmin-theme setupfile from jsDelivr CDN
(setq org-safe-remote-resources
      '("\\`https://cdn\\.jsdelivr\\.net/gh/yuqiuj-mob/orgmin-theme@"))

(setq org-latex-src-block-backend 'engraved)
(setq org-latex-pdf-process (list
   "latexmk -pdflatex='lualatex -shell-escape -interaction nonstopmode' -pdf -f  %f"))

(org-babel-do-load-languages
    'org-babel-load-languages
    '((mermaid . t)
      (scheme . t)
      (shell . t)))

(defun org-babel-execute:wavedrom (body params)
  "Execute a block of WaveDrom code with org-babel."
  (let* ((tmp-src-file (org-babel-temp-file "wavedrom-" ".json"))
         (tmp-out-file (org-babel-temp-file "wavedrom-" ".svg"))
         (cmd (format "wavedrom-cli -i %s -s > %s"
                      (shell-quote-argument tmp-src-file)
                      (shell-quote-argument tmp-out-file))))
    (with-temp-file tmp-src-file (insert body))
    (shell-command cmd)
    (org-babel-result-cond
        (cdr (assq :file params))
      (copy-file tmp-out-file (cdr (assq :file params)) t)
      (format "[[file:%s]]" tmp-out-file))))

(add-to-list 'org-src-lang-modes '("wavedrom" . json))

(defun org-babel-execute:asm (body params)
  "Execute a block of NASM assembly code with org-babel."
  (let* ((tmp-dir       (make-temp-file "babel-nasm-" t))
         (asm-file      (expand-file-name "code.asm" tmp-dir))
         (obj-file      (expand-file-name "code.o" tmp-dir))
         (bin-file      (expand-file-name "code.out" tmp-dir))
         (output-buffer (generate-new-buffer "*nasm-output*")))
    (with-temp-file asm-file (insert body))
    (unwind-protect
        (progn
          (unless (zerop (call-process "nasm" nil output-buffer t
                                       "-felf64" asm-file "-o" obj-file))
            (error "NASM compilation failed: %s"
                   (with-current-buffer output-buffer (buffer-string))))
          (unless (zerop (call-process "ld" nil output-buffer t
                                       "-o" bin-file obj-file))
            (error "Linking failed: %s"
                   (with-current-buffer output-buffer (buffer-string))))
          (with-temp-buffer
            (call-process bin-file nil t)
            (buffer-string)))
      (kill-buffer output-buffer))))

(setq org-roam-capture-templates
         '(("d" "default" plain
            "%?"
            :target (file+head "%<%Y%m%d%H%M%S>-${slug}.org"
                               "#+title: ${title}\n#+OPTIONS: author:nil\n#+OPTIONS: date:nil\n#+OPTIONS: ^:{}\n#+OPTIONS: num:nil\n#+SETUPFILE: https://cdn.jsdelivr.net/gh/yuqiuj-mob/orgmin-theme@main/bootstrap-orgdoc.setup")
            :unnarrowed t)

           ("t" "task board" plain
            "\n* TODO %?"
            :target (file+head "boards/${slug}.org"
                               "#+title: Board: ${title}\n#+filetags: :board:\n")
            :unnarrowed t)

           ("m" "meeting" plain
            "* Meeting Notes\n%?\n** Agenda\n- \n"
            :target (file+head "meetings/%<%Y%m%d%H%M%S>-${slug}.org"
                               "#+title: Meeting: ${title}\n#+filetags: :meeting:\n")
            :unnarrowed t)

           ("n" "design note" plain
            "* Specification\n%?\n* Modules\n \n* Tests\n \n* Notes\n"
            :target (file+head "design-notes/%<%Y%m%d%H%M%S>-${slug}.org"
                               "#+title: Design: ${title}\n#+filetags: :design:\n#+OPTIONS: author:nil\n#+OPTIONS: date:nil\n#+OPTIONS: toc:nil\n#+LATEX_HEADER: \\usepackage[letterpaper,margin=1in]{geometry}\n")
            :unnarrowed t)

           ("b" "buglog" plain
            "* Link to buglog\n%?\n* Tests\n \n* Probes\n \n* Notes \n"
            :target (file+head "buglogs/%<%Y%m%d%H%M%S>-${slug}.org"
                               "#+title: Buglog: ${title}\n#+filetags: :buglog:\n")
            :unnarrowed t)

           ("p" "paper" plain "* Summary\n%?\n* Claims\n -\n* Notes\n\n* References\n \n* Related Links"
               :target (file+head "papers/${slug}.org" "#+TITLE: ${title}\n#+AUTHOR: ${author}\n#+DATE: ${date}\n")
               :unnarrowed t)))

(use-package! org-roam-bibtex
  :after org-roam
  :init (require 'org-ref)
  :hook (org-roam-mode . org-roam-bibtex-mode)
  :config
  (setq orb-preformat-keywords
        '(("citekey" . "=key=") "title" "url" "file" "author-or-editor" "keywords"))
  (setq orb-process-file-field t)
  (setq orb-file-field-extensions '("pdf")))

(defvar rj/study-project-paper-dirs
  '("/home/rjiang/Documents/secure-study/papers")
  "Per-project paper directories that citar should search for PDFs.
Append a path here when starting a new study project so PDFs added to
pubs with `pubs add -L' (link, no copy) remain discoverable from citar.")

(defun rj/pubs-refresh ()
  "Rescan ~/.pubs/bib/ and refresh citar bibliography + library paths.
Call after `pubs add' or `pubs remove' to pick up changes without
restarting Emacs."
  (interactive)
  (let ((bibs (directory-files-recursively "/home/rjiang/.pubs/bib/" "\\.bib$")))
    (setq reftex-default-bibliography bibs
          org-ref-default-bibliography bibs
          bibtex-completion-bibliography bibs
          citar-bibliography bibs)
    (setq citar-library-paths
          (cons "/home/rjiang/.pubs/doc" rj/study-project-paper-dirs))
    (when (fboundp 'citar-cache--invalidate) (citar-cache--invalidate))
    (message "pubs refreshed: %d bibs, %d library paths"
             (length bibs) (length citar-library-paths))))

(setq bibtex-completion-library-path "/home/rjiang/.pubs/doc")

(after! citar
  (rj/pubs-refresh)
  (setq! citar-notes-paths '("/home/rjiang/.pubs/notes")))

(setq org-format-latex-options (plist-put org-format-latex-options :scale 2.0))
(setq org-format-latex-options (plist-put org-format-latex-options :dpi 300))

(use-package! websocket
  :after org-roam)
