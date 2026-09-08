;;; -*- lexical-binding: t; -*-   ; first line of the tangled lang-verilog.el
(use-package! verilog-ts-mode
    :config
    (setq verilog-ts-indent-level 3)
    (setq verilog-auto-newline nil))

;; Drop the advice from the earlier instance-only version so a config reload
;; doesn't leave it stacked on the stock index builder.
(after! verilog-ts-mode
  (dolist (adv '((verilog-ts--node-identifier-name . verilog-ts--node-identifier-name@verilog-ts-imenu-instance-name)
                 (verilog-ts--node-identifier-name . verilog-ts--node-identifier-name@my/verilog-ts-imenu-instance-name)
                 (verilog-ts--imenu-create-index   . verilog-ts--imenu-create-index@my/verilog-ts-imenu-flag)))
    (advice-remove (car adv) (cdr adv))))

(require 'cl-lib)
(require 'treesit)
(require 'imenu)

(defconst my/verilog-ts-imenu-name-width-cap 40
  "Upper bound for the name column, so one long name can't push the rest right.")

(defconst my/verilog-ts-imenu-gap 2
  "Minimum spaces between the name and detail columns.")

(defconst my/verilog-ts-imenu-local-scope-re
  (rx bos (or "statement" "function_body_declaration" "task_body_declaration"
              "struct_union_member" "class_declaration" "tf_port_item")
      eos)
  "Node types whose descendants are locals, not module-scope signals.")

;;; helpers

(defun my/verilog-ts-imenu--text (node)
  "Whitespace-collapsed text of NODE, or nil if NODE is nil or blank."
  (when node
    (let ((s (string-trim (replace-regexp-in-string "[ \t\n]+" " " (treesit-node-text node t)))))
      (unless (string-empty-p s) s))))

(defun my/verilog-ts-imenu--nodes (regexp)
  "All nodes in the buffer whose type matches REGEXP, in buffer order."
  (let (acc)
    (cl-labels ((walk (tree)
                  (when (car tree) (push (car tree) acc))
                  (mapc #'walk (cdr tree))))
      (when-let* ((tree (treesit-induce-sparse-tree (treesit-buffer-root-node) regexp nil 1000)))
        (walk tree)))
    (nreverse acc)))

(defun my/verilog-ts-imenu--child (node regexp)
  "First direct named child of NODE whose type matches REGEXP."
  (treesit-search-subtree node regexp nil nil 1))

(defun my/verilog-ts-imenu--ancestor (node regexp)
  "Nearest ancestor of NODE whose type matches REGEXP, or nil."
  (let ((p (treesit-node-parent node)))
    (while (and p (not (string-match-p regexp (treesit-node-type p))))
      (setq p (treesit-node-parent p)))
    p))

(defun my/verilog-ts-imenu--trunc (s n)
  (if (and s (> (length s) n)) (concat (substring s 0 (1- n)) "…") s))

(defun my/verilog-ts-imenu--dims (node name-node)
  "Text of NODE after NAME-NODE and before any `=', e.g. unpacked dims `[0:15]'."
  (let* ((s (buffer-substring-no-properties (treesit-node-end name-node) (treesit-node-end node)))
         (d (string-trim (replace-regexp-in-string "[ \t\n]+" " " (car (split-string s "="))))))
    (unless (string-empty-p d) d)))

(defun my/verilog-ts-imenu--join (&rest parts)
  (string-join (delq nil parts) " "))

;;; categories: each returns ((NAME DETAIL POS) ...)

(defun my/verilog-ts-imenu--modules ()
  (cl-loop for n in (my/verilog-ts-imenu--nodes
                     (rx bos (or "module" "interface" "program" "package" "class") "_declaration" eos))
           for name = (or (ignore-errors (verilog-ts--node-identifier-name n))
                          (treesit-node-text (treesit-search-subtree n (rx bos "simple_identifier" eos)) t))
           for kind = (car (split-string (treesit-node-type n) "_"))
           when name collect (list name kind (treesit-node-start n))))

(defun my/verilog-ts-imenu--ports ()
  "ANSI and non-ANSI ports.
A continuation port (`input logic a, b') inherits the header of `a'."
  (let (acc header last-parent)
    (dolist (n (my/verilog-ts-imenu--nodes (rx bos (? "ansi_") "port_declaration" eos)))
      (if (string= (treesit-node-type n) "port_declaration")
          ;; non-ANSI: (port_declaration (input_declaration [type] (list_of_*_identifiers id...)))
          (let* ((decl (treesit-node-child n 0 t))
                 (dir (car (split-string (treesit-node-type decl) "_")))
                 (type (my/verilog-ts-imenu--text (my/verilog-ts-imenu--child decl "_port_type\\'")))
                 (ids (my/verilog-ts-imenu--child decl (rx bos "list_of_")))
                 (ids (and ids (treesit-node-children ids t))))
            (dolist (id ids)
              (when (string= (treesit-node-type id) "simple_identifier")
                (push (list (treesit-node-text id t) (my/verilog-ts-imenu--join dir type) (treesit-node-start id)) acc))))
        (let* ((parent (treesit-node-parent n))
               (name-node (treesit-node-child-by-field-name n "port_name"))
               (name (and name-node (treesit-node-text name-node t)))
               (hdr (my/verilog-ts-imenu--text (my/verilog-ts-imenu--child n "_port_header\\'"))))
          (unless (equal parent last-parent) (setq header nil last-parent parent))
          (when hdr (setq header hdr))
          (when name
            (push (list name (my/verilog-ts-imenu--join header (my/verilog-ts-imenu--dims n name-node))
                        (treesit-node-start n))
                  acc)))))
    (nreverse acc)))

(defun my/verilog-ts-imenu--params ()
  "parameter / localparam in the #( ) header and the body; one entry per name."
  (cl-loop for n in (my/verilog-ts-imenu--nodes (rx bos (or "param" "type") "_assignment" eos))
           for name = (treesit-node-text (my/verilog-ts-imenu--child n (rx bos "simple_identifier" eos)) t)
           for decl = (my/verilog-ts-imenu--ancestor n (rx bos (? "local_") "parameter_declaration" eos))
           for kw = (if (and decl (string-prefix-p "local" (treesit-node-type decl))) "localparam" "parameter")
           for type = (if (string= (treesit-node-type n) "type_assignment") "type"
                        (my/verilog-ts-imenu--text
                         (and decl (my/verilog-ts-imenu--child decl (rx bos "data_type_or_implicit" eos)))))
           for val = (and (> (treesit-node-child-count n t) 1)
                          (my/verilog-ts-imenu--text (treesit-node-child n -1 t)))
           for detail = (string-join (delq nil (list kw type (and val (concat "= " (my/verilog-ts-imenu--trunc val 24))))) " ")
           when name collect (list name detail (treesit-node-start n))))

(defun my/verilog-ts-imenu--typedefs ()
  (cl-loop for n in (my/verilog-ts-imenu--nodes (rx bos "type_declaration" eos))
           for name = (treesit-node-text (treesit-node-child-by-field-name n "type_name") t)
           for dt = (my/verilog-ts-imenu--text (my/verilog-ts-imenu--child n (rx bos (or "data" "class") "_type" eos)))
           for detail = (my/verilog-ts-imenu--trunc (string-trim (car (split-string (or dt "") "{"))) 30)
           when name collect (list name detail (treesit-node-start n))))

(defun my/verilog-ts-imenu--signals ()
  "Module-scope nets, variables and genvars.
Locals inside always/function/task bodies are skipped."
  (let (acc)
    (dolist (n (my/verilog-ts-imenu--nodes
                (rx bos (or "variable_decl_assignment" "net_decl_assignment" "genvar_declaration") eos)))
      (unless (my/verilog-ts-imenu--ancestor n my/verilog-ts-imenu-local-scope-re)
        (if (string= (treesit-node-type n) "genvar_declaration")
            (when-let* ((names (my/verilog-ts-imenu--text
                               (my/verilog-ts-imenu--child n (rx bos "list_of_genvar_identifiers" eos)))))
              (push (list names "genvar" (treesit-node-start n)) acc))
          (let* ((decl (treesit-node-parent (treesit-node-parent n)))   ; list_of_* -> declaration
                 (name-node (my/verilog-ts-imenu--child n (rx bos "simple_identifier" eos)))
                 (name (and name-node (treesit-node-text name-node t)))
                 (type (cl-loop for c in (treesit-node-children decl t)
                                until (string-prefix-p "list_of_" (treesit-node-type c))
                                for s = (my/verilog-ts-imenu--text c)
                                when s collect s)))
            (when name
              (push (list name
                          (my/verilog-ts-imenu--join (my/verilog-ts-imenu--trunc (string-join type " ") 30)
                                                     (my/verilog-ts-imenu--dims n name-node))
                          (treesit-node-start n))
                    acc))))))
    (nreverse acc)))

(defun my/verilog-ts-imenu--instances ()
  "One entry per instance name; the module/interface type is the detail column."
  (cl-loop for n in (my/verilog-ts-imenu--nodes (rx bos "hierarchical_instance" eos))
           for name = (my/verilog-ts-imenu--text (my/verilog-ts-imenu--child n (rx bos "name_of_instance" eos)))
           for type = (treesit-node-text
                       (my/verilog-ts-imenu--child (treesit-node-parent n) (rx bos "simple_identifier" eos)) t)
           when name collect (list name (or type "") (treesit-node-start n))))

(defun my/verilog-ts-imenu--always ()
  "always/initial/final blocks.
Name is the `begin : label' if present, else the keyword; sensitivity as detail."
  (cl-loop for n in (my/verilog-ts-imenu--nodes (rx bos (or "always" "initial" "final") "_construct" eos))
           for kw = (or (my/verilog-ts-imenu--text (my/verilog-ts-imenu--child n (rx bos "always_keyword" eos)))
                        (car (split-string (treesit-node-type n) "_")))
           for stmt = (or (my/verilog-ts-imenu--text (my/verilog-ts-imenu--child n (rx bos "statement" eos))) "")
           for label = (and (string-match (rx bos (* nonl) "begin" (* space) ":" (* space) (group (+ (any word "_$")))) stmt)
                            (match-string 1 stmt))
           for ev = (and (string-match (rx bos "@" (* space) "(" (group (* (not (any ")")))) ")") stmt)
                         (concat "@(" (my/verilog-ts-imenu--trunc (match-string 1 stmt) 40) ")"))
           collect (list (or label kw)
                         (string-join (delq nil (list (and label kw) ev)) " ")
                         (treesit-node-start n))))

(defun my/verilog-ts-imenu--functions ()
  (cl-loop for n in (my/verilog-ts-imenu--nodes (rx bos (or "function" "task") "_declaration" eos))
           for name = (ignore-errors (verilog-ts--node-identifier-name n))
           for kw = (car (split-string (treesit-node-type n) "_"))
           for ret = (my/verilog-ts-imenu--text
                      (treesit-search-subtree n (rx bos "data_type_or_void" eos) nil nil 2))
           when name collect (list name (string-join (delq nil (list kw ret)) " ") (treesit-node-start n))))

(defun my/verilog-ts-imenu--generates ()
  "Named generate blocks (`begin : g_name'), with the construct kind as detail."
  (cl-loop for n in (my/verilog-ts-imenu--nodes (rx bos "generate_block" eos))
           for name = (treesit-node-text (treesit-node-child-by-field-name n "name") t)
           for parent = (treesit-node-type (treesit-node-parent n))
           for kind = (cond ((string-prefix-p "loop" parent) "for")
                            ((string-match-p "\\`\\(if\\|conditional\\)" parent) "if")
                            ((string-prefix-p "case" parent) "case")
                            (t "generate"))
           when name collect (list name kind (treesit-node-start n))))

;;; assembly

(defvar my/verilog-ts-imenu-categories
  '(("Modules"    my/verilog-ts-imenu--modules    font-lock-keyword-face)
    ("Ports"      my/verilog-ts-imenu--ports      font-lock-variable-name-face)
    ("Parameters" my/verilog-ts-imenu--params     font-lock-constant-face)
    ("Typedefs"   my/verilog-ts-imenu--typedefs   font-lock-type-face)
    ("Signals"    my/verilog-ts-imenu--signals    font-lock-variable-name-face)
    ("Instances"  my/verilog-ts-imenu--instances  font-lock-function-name-face)
    ("Always"     my/verilog-ts-imenu--always     font-lock-keyword-face)
    ("Functions"  my/verilog-ts-imenu--functions  font-lock-function-name-face)
    ("Generates"  my/verilog-ts-imenu--generates  font-lock-keyword-face))
  "Imenu categories: (LABEL COLLECTOR NAME-FACE), in display order.")

(defun my/verilog-ts-imenu--format (entries face)
  "Turn ((NAME DETAIL POS) ...) into imenu entries with aligned two-column labels."
  (let ((width (min my/verilog-ts-imenu-name-width-cap
                    (apply #'max 0 (mapcar (lambda (e) (length (car e))) entries)))))
    (mapcar (lambda (e)
              (pcase-let ((`(,name ,detail ,pos) e))
                (cons (if (string-empty-p detail)
                          (propertize name 'face face)
                        (concat (propertize (format (format "%%-%ds" width) name) 'face face)
                                (make-string my/verilog-ts-imenu-gap ?\s)
                                (propertize detail 'face 'shadow)))
                      (if imenu-use-markers (copy-marker pos) pos))))
            entries)))

(defun my/verilog-ts-imenu-create-index ()
  "Imenu index for `verilog-ts-mode', grouped by category like the Elisp one."
  (cl-loop for (cat fn face) in my/verilog-ts-imenu-categories
           for entries = (condition-case err
                             (funcall fn)
                           (error (message "imenu %s: %S" cat err) nil))
           when entries collect (cons cat (my/verilog-ts-imenu--format entries face))))

(defun my/verilog-ts-imenu-enable ()
  (setq-local imenu-create-index-function #'my/verilog-ts-imenu-create-index))

;; Depth 90: run after `verilog-ext-mode' (hooked at 0) so this index wins.
(add-hook 'verilog-ts-mode-hook #'my/verilog-ts-imenu-enable 90)

;; Narrowing keys and faces for `consult-imenu' (SPC s i), like the Elisp preset.
(after! consult-imenu
  (setf (alist-get 'verilog-ts-mode consult-imenu-config)
        '(:toplevel "Modules"
          :types ((?m "Modules"    font-lock-keyword-face)
                  (?p "Ports"      font-lock-variable-name-face)
                  (?P "Parameters" font-lock-constant-face)
                  (?t "Typedefs"   font-lock-type-face)
                  (?s "Signals"    font-lock-variable-name-face)
                  (?i "Instances"  font-lock-function-name-face)
                  (?a "Always"     font-lock-keyword-face)
                  (?f "Functions"  font-lock-function-name-face)
                  (?g "Generates"  font-lock-keyword-face)))))

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
