(setq user-full-name "Rick Jiang"
      user-mail-address "yuqiujp@gmail.com")
(setq mac-command-modifier 'meta)
(setq large-file-warning-threshold nil)

(setq default-frame-alist '((undecorated . t)))
(scroll-bar-mode -1)
(setq doom-theme 'modus-vivendi-deuteranopia)

(defun col-strip (col-str)
  "Convert a dash-separated hex color string into a list of #RRGGBB strings."
  (butlast (split-string (mapconcat (lambda (x) (concat "#" x " "))
                                    (split-string col-str "-")
                                    "") " ")))

(setq my/org-heading-colors
      (col-strip "f94144-f3722c-f8961e-f9844a-f9c74f-90be6d-43aa8b-4d908e-577590-277da1"))

(after! org
  (custom-set-faces!
    `(outline-1   :foreground ,(nth 0 my/org-heading-colors))
    `(outline-2   :foreground ,(nth 1 my/org-heading-colors))
    `(outline-3   :foreground ,(nth 2 my/org-heading-colors))
    `(outline-4   :foreground ,(nth 3 my/org-heading-colors))
    `(outline-5   :foreground ,(nth 4 my/org-heading-colors))
    `(outline-6   :foreground ,(nth 5 my/org-heading-colors))
    `(org-level-1 :foreground ,(nth 0 my/org-heading-colors))
    `(org-level-2 :foreground ,(nth 1 my/org-heading-colors))
    `(org-level-3 :foreground ,(nth 2 my/org-heading-colors))
    `(org-level-4 :foreground ,(nth 3 my/org-heading-colors))
    `(org-level-5 :foreground ,(nth 4 my/org-heading-colors))
    `(org-level-6 :foreground ,(nth 5 my/org-heading-colors))))

(setq doom-font (font-spec :family "FiraCode Nerd Font" :size 11.0))

(plist-put! +ligatures-extra-symbols
            :and nil :or nil :for nil :not nil :true nil :false nil
            :int nil :float nil :str nil :bool nil :list nil)

(remove-hook '+doom-dashboard-functions #'doom-dashboard-widget-shortmenu)
(add-hook! '+doom-dashboard-functions :append
(setq-hook! '+doom-dashboard-mode-hook evil-normal-state-cursor (list nil))
(setq fancy-splash-image (concat doom-user-dir "origami.png")))

(setq display-line-numbers-type 'relative)
