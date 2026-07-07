;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
(setq user-full-name "Eliseu Venites Filho"
      user-mail-address "evf@if-ufrgs")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-unicode-font' -- for unicode glyphs
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
(setq doom-font (font-spec :family "Fira Code" :size 11 :weight 'semi-light)
     doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-tokyo-night)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type 'relative)

;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

;; Better defaults
(setq-default
 delete-by-moving-to-trash t                      ; Delete files to trash
 window-combination-resize t                      ; take new window space from all other windows (not just current)
 x-stretch-cursor t)                              ; Stretch cursor to the glyph width

(setq undo-limit 80000000                         ; Raise undo-limit to 80Mb
      evil-want-fine-undo t                       ; By default while in insert all changes are one big blob. Be more granular
      auto-save-default t                         ; Nobody likes to loose work, I certainly don't
      truncate-string-ellipsis "…"                ; Unicode ellispis are nicer than "...", and also save /precious/ space
      password-cache-expiry nil                   ; I can trust my computers ... can't I?
      ;; scroll-preserve-screen-position 'always     ; Don't have `point' jump around
      scroll-margin 2                            ; It's nice to maintain a little margin
      evil-kill-on-visual-paste nil)

(global-subword-mode t)                           ; Recognize uppercase letters as word boundaries (useful for CamelCase naming)

;; ;; Dired
;; (evil-define-key 'normal dired-mode-map
;;   (kbd "M-RET") 'dired-display-file
;;   (kbd "h") 'dired-up-directory
;;   (kbd "l") 'dired-open-file ; use dired-find-file instead of dired-open.
;;   (kbd "m") 'dired-mark
;;   (kbd "t") 'dired-toggle-marks
;;   (kbd "u") 'dired-unmark
;;   (kbd "C") 'dired-do-copy
;;   (kbd "D") 'dired-do-delete
;;   (kbd "J") 'dired-goto-file
;;   (kbd "M") 'dired-do-chmod
;;   (kbd "O") 'dired-do-chown
;;   (kbd "P") 'dired-do-print
;;   (kbd "R") 'dired-do-rename
;;   (kbd "T") 'dired-do-touch
;;   (kbd "Y") 'dired-copy-filenamecopy-filename-as-kill ; copies filename to kill ring.
;;   (kbd "Z") 'dired-do-compress
;;   (kbd "+") 'dired-create-directory
;;   (kbd "-") 'dired-do-kill-lines
;;   (kbd "% l") 'dired-downcase
;;   (kbd "% m") 'dired-mark-files-regexp
;;   (kbd "% u") 'dired-upcase
;;   (kbd "* %") 'dired-mark-files-regexp
;;   (kbd "* .") 'dired-mark-extension
;;   (kbd "* /") 'dired-mark-directories
;;   (kbd "; d") 'epa-dired-do-decrypt
;;   (kbd "; e") 'epa-dired-do-encrypt)

;; Make popups open on the right
(set-popup-rules!
  '(("^ \\*" :slot -1)
    ("^\\*" :select t)
    ("^\\*Completions" :slot -1 :ttl 0)
    ("^\\*\\(?:scratch\\|Messages\\)" :ttl t)
    ("^\\*Help" :slot -1 :size 0.2 :select t)
    ("^\\*doom:" :size 0.3 :select t :modeline t :quit t :ttl t :side right)))

;; Enable vertical and horizontal splitting
(setq evil-vsplit-window-right t
      evil-split-window-below t)

;; Ask which buffer (with preview) to open when window is split:
(defadvice! prompt-for-buffer (&rest _)
  :after '(evil-window-split evil-window-vsplit)
  (consult-buffer))

;; Remove window decoration
(setq default-frame-alist '((undecorated . t)))

;; Default mode
(setq-default major-mode 'org-mode)

;; vterm
(use-package! vterm
  :ensure t)
(after! vterm
  (set-popup-rule! "*doom:vterm-popup:main" :size 0.3 :vslot -4 :select t :quit nil :ttl 0 :side 'right))

;; Org-mode

;; Directories
(setq org-directory "~/Documents/org/"
      org-agenda-files '("~/Documents/org/")
      org-capture-journal-file "~/Documents/org/journal.org"
      org-use-property-inheritance t       ; It's convenient to have properties inherited.
      org-log-done 'time                   ; Having the time a item is done sounds convenient.
      org-catch-invisible-edits 'smart     ; Try not to accidently do weird stuff in invisible regions.
      org-hide-emphasis-markers t)

;; LaTeX classes
(require 'ox-latex)
(unless (boundp 'org-latex-classes)
  (setq org-latex-classes nil))
(add-to-list 'org-latex-classes
             '("note"
               "\\documentclass{article}[a4]
                \\usepackage[margin=0.5in]{geometry}"
               ("\\section{%s}" . "\\section*{%s}")
               ("\\subsection{%s}" . "\\subsection*{%s}")
               ("\\subsubsection{%s}" . "\\subsubsection*{%s}")
               ("\\paragraph{%s}" . "\\paragraph*{%s}")
               ("\\subparagraph{%s}" . "\\subparagraph*{%s}")))

;; Default latex packages
(setq org-latex-packages-alist '(
                                 ;; AMS packages
                                 ("" "amsmath" t)
                                 ("" "amsthm" t)
                                 ("" "amssymb" t)
                                 ;; Extended math
                                 ("" "mathtools" t)
                                 ;; Dirac braket notation
                                 ("" "braket" t)
                                 ;; Color names
                                 ("dvipsnames" "xcolor" t)
                                 ;; Cancel terms
                                 ("" "cancel" t)))

;; Default bibliography file
(setq reftex-default-bibliography
      '("~/Zotero/my_library.bib"))

;;Fix LaTeX export with svg images ([[https://emacs.stackexchange.com/a/47462][Answer]]).
 (setq org-latex-pdf-process
       (let
           ((cmd (concat "latexmk -f -pdf -%latex -shell-escape -interaction=nonstopmode"
                 " --synctex=1"
                 " -output-directory=%o %f")))
         (list cmd
           "cd %o; if test -r %b.idx; then makeindex %b.idx; fi"
           "cd %o; bibtex %b"
           cmd
           cmd)))

;; Subfigures
(org-link-set-parameters
 "subfig"
 :follow (lambda (file) (find-file file))
 :face '(:foreground "chocolate" :weight bold :underline t)
 :display 'full
 :export (lambda (file desc backend)
           (when (eq backend 'latex)
             (if (string-match ">(\\(.+\\))" desc)
                 (concat "\\subfigure[" (replace-regexp-in-string "\s+>(.+)" "" desc) "]"
                         "{\\includegraphics"
                         "["
                         (match-string 1 desc)
                         "]"
                         "{"
                         file
                         "}}")
               (format "\\subfigure[%s]{\\includegraphics{%s}}" desc file)))))

;; Use =Zotero= library:
(after! citar
  (setq org-cite-global-bibliography '("~/Zotero/my_library.bib"))
  (setq bibtex-completion-bibliography '("~/Zotero/my_library.bib"))
  (setq citar-bibliography '("~/Zotero/my_library.bib"))
  (setq citar-library-paths '("~/Zotero/storage/"))
  (setq citar-citeproc-csl-styles-dir (expand-file-name "~/Zotero/styles"))
  (setq citar-citeproc-csl-style "american-physics-society.csl")
  (setq citar-symbols
        `((file ,(all-the-icons-faicon "file-o" :face 'all-the-icons-green :v-adjust -0.1) . " ")
          (note ,(all-the-icons-material "speaker_notes" :face 'all-the-icons-blue :v-adjust -0.3) . " ")
          (link ,(all-the-icons-octicon "link" :face 'all-the-icons-orange :v-adjust 0.01) . " "))))

;; Import CSL citation styles and bibliography from =Zotero=:
(after! oc-csl
  (setq org-cite-csl-styles-dir (expand-file-name "~/Zotero/styles")
        org-cite-csl--fallback-style-file "american-physics-society.csl"))

;; Citation command under Org's localleader:
(map! :after org
      :map org-mode-map
      :localleader
      :desc "Insert citation" "@" #'org-cite-insert)

;; Function that attempts to convert =org-ref= citations to =org-cite= forms:
(after! oc
  (defun org-ref-to-org-cite ()
    "Attempt to convert org-ref citations to org-cite syntax."
    (interactive)
    (let* ((cite-conversions '(("cite" . "//b") ("Cite" . "//bc")
                               ("nocite" . "/n")
                               ("citep" . "") ("citep*" . "//f")
                               ("parencite" . "") ("Parencite" . "//c")
                               ("citeauthor" . "/a/f") ("citeauthor*" . "/a")
                               ("citeyear" . "/na/b")
                               ("Citep" . "//c") ("Citealp" . "//bc")
                               ("Citeauthor" . "/a/cf") ("Citeauthor*" . "/a/c")
                               ("autocite" . "") ("Autocite" . "//c")
                               ("notecite" . "/l/b") ("Notecite" . "/l/bc")
                               ("pnotecite" . "/l") ("Pnotecite" . "/l/bc")))
           (cite-regexp (rx (regexp (regexp-opt (mapcar #'car cite-conversions) t))
                            ":" (group (+ (not (any "\n     ,.)]}")))))))
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward cite-regexp nil t)
          (message (format "[cite%s:@%s]"
                                 (cdr (assoc (match-string 1) cite-conversions))
                                 (match-string 2)))
          (replace-match (format "[cite%s:@%s]"
                                 (cdr (assoc (match-string 1) cite-conversions))
                                 (match-string 2))))))))

;; Julia

;; Do not use built-in package
(setq lsp-julia-package-dir nil)
;; Select Julia environment
(setq lsp-julia-default-environment "~/.julia/environments/v1.8")

;; Julia REPL
(after! julia-repl
  ;; Use vterm
  (julia-repl-set-terminal-backend 'vterm)
  ;; Open REPL at the right side
  (set-popup-rule! "*julia:\*" :side 'right :size 0.3 :ttl 0 :quit nil :select nil)
  ;; Set environment variables
  (setenv "JULIA_NUM_THREADS" "7"))

;; Python

;; (add-hook 'python-mode-hook 'lsp)

;; Anaconda

(require 'conda)
;; (custom-set-variables
;;  '(conda-anaconda-home "/opt/miniconda3/"))
(setq
 conda-anaconda-home (expand-file-name "~/anaconda3/")
 conda-env-home-directory (expand-file-name "~/anaconda3/")
 conda-env-subdirectory "envs")
;; (add-hook 'conda-postactivate-hook 'python-mode)
