(setq user-full-name "Rick Jiang"
      user-mail-address "yuqiujp@gmail.com")
(setq mac-command-modifier 'meta)
(setq large-file-warning-threshold nil)

(setq default-frame-alist '((undecorated . t)))
(scroll-bar-mode -1)

;; Must be set before the theme is enabled (Doom does that after this file).
(setq modus-themes-common-palette-overrides
      '(;; line-number column blends into the main background
        (bg-line-number-active   bg-main)
        (bg-line-number-inactive bg-main)
        (fg-line-number-inactive "gray45")
        ;; borderless, blended mode line
        (border-mode-line-active   bg-mode-line-active)
        (border-mode-line-inactive bg-mode-line-inactive)
        ;; subtle fringe so it doesn't draw a visible edge
        (fringe unspecified)))

;; Bold keywords/types/etc. (comments stay upright — italic left off).
(setq modus-themes-bold-constructs t)
(setq modus-themes-italic-constructs nil)

(setq doom-theme 'modus-vivendi)

;; :weight medium counters the thinner XWayland/X11 font rendering.
(setq doom-font (font-spec :family "FiraCode Nerd Font" :size 11.0 :weight 'medium))
;; Proportional font for org prose via mixed-pitch (Charter = serif alt).
(setq doom-variable-pitch-font (font-spec :family "Lato" :size 12.0))

(plist-put! +ligatures-extra-symbols
            :and nil :or nil :for nil :not nil :true nil :false nil
            :int nil :float nil :str nil :bool nil :list nil)

(use-package! spacious-padding
  :config
  ;; nil: modus's palette overrides already give a borderless mode line, and
  ;; the subtle path builds an invalid ':underline (:color unspecified ...)'
  ;; that Emacs 31 rejects at frame init.
  (setq spacious-padding-subtle-mode-line nil)
  ;; Thin bezel + minimal mode-line box. Defaults are 15 border / 6 mode-line,
  ;; which read as too aggressive; doom-modeline is already font-height+4 tall,
  ;; so the extra mode-line height was this box.
  (setq spacious-padding-widths
        '( :internal-border-width 5
           :header-line-width 2
           :mode-line-width 2
           :tab-width 2
           ;; keep the divider thin — a wide one leaves a background-colored
           ;; gap through the mode line at side-by-side split boundaries
           :right-divider-width 1
           :scroll-bar-width 0
           :fringe-width 6))
  (spacious-padding-mode 1))

(use-package! pulsar
  :config
  (setq pulsar-pulse t
        pulsar-delay 0.055)
  (pulsar-global-mode 1))

(use-package! lin
  :config
  (setq lin-face 'lin-cyan)
  (lin-global-mode 1))

(after! doom-modeline
  (setq doom-modeline-buffer-file-name-style 'relative-to-project
        doom-modeline-buffer-encoding nil
        doom-modeline-vcs-max-length 15
        doom-modeline-enable-word-count t))

(remove-hook '+doom-dashboard-functions #'doom-dashboard-widget-shortmenu)
(add-hook! '+doom-dashboard-functions :append
(setq-hook! '+doom-dashboard-mode-hook evil-normal-state-cursor (list nil))
(setq fancy-splash-image (concat doom-user-dir "origami.png")))

(setq display-line-numbers-type 'relative)
