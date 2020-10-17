;;; email/mu4e/config.el -*- lexical-binding: t; -*-

(defvar +mu4e-backend 'mbsync
  "Which backend to use. Can either be offlineimap, mbsync or nil (manual).")


;;
;;; Packages

(use-package! mu4e
  :commands mu4e mu4e-compose-new
  :init
  (provide 'html2text) ; disable obsolete package
  (when (or (not (require 'mu4e-meta nil t))
            (version< mu4e-mu-version "1.4"))
    (setq mu4e-maildir "~/.mail"
          mu4e-user-mail-address-list nil))
  (setq mu4e-attachment-dir
        (lambda (&rest _)
          (expand-file-name ".attachments" (mu4e-root-maildir))))
  :config
  (pcase +mu4e-backend
    (`mbsync
     (setq mu4e-get-mail-command "mbsync -a"
           mu4e-change-filenames-when-moving t))
    (`offlineimap
     (setq mu4e-get-mail-command "offlineimap -o -q")))

  (setq mu4e-update-interval nil
        mu4e-compose-format-flowed t ; visual-line-mode + auto-fill upon sending
        mu4e-view-show-addresses t
        mu4e-sent-messages-behavior 'sent
        mu4e-hide-index-messages t
        ;; try to show images
        mu4e-view-show-images t
        mu4e-view-image-max-width 800
        mu4e-view-use-gnus t ; the way of the future: https://github.com/djcb/mu/pull/1442#issuecomment-591695814
        ;; configuration for sending mail
        message-send-mail-function #'smtpmail-send-it
        smtpmail-stream-type 'starttls
        message-kill-buffer-on-exit t ; close after sending
        ;; start with the first (default) context;
        mu4e-context-policy 'pick-first
        ;; compose with the current context, or ask
        mu4e-compose-context-policy 'ask-if-none
        ;; use helm/ivy
        mu4e-completing-read-function
        (cond ((featurep! :completion ivy) #'ivy-completing-read)
              ((featurep! :completion helm) #'completing-read)
              (t #'ido-completing-read))
        ;; no need to ask
        mu4e-confirm-quit nil
        ;; remove 'lists' column
        mu4e-headers-fields
        '((:account . 12)
          (:human-date . 12)
          (:flags . 4)
          (:from . 25)
          (:subject)))

  ;; set mail user agent
  (setq mail-user-agent 'mu4e-user-agent)

  ;;----------------
  ;; Icons
  ;;----------------

  ;; Icons need a bit of work
  ;; Spacing needs to be determined and adjucted

  (defun +get-string-width (str)
    "Return the width in pixels of a string in the current
window's default font. If the font is mono-spaced, this
will also be the width of all other printable characters."
    (let ((window (selected-window))
          (remapping face-remapping-alist))
      (with-temp-buffer
        (make-local-variable 'face-remapping-alist)
        (setq face-remapping-alist remapping)
        (set-window-buffer window (current-buffer))
        (insert str)
        (car (window-text-pixel-size)))))

  (cl-defun mu4e~normalised-icon (name &key set colour height v-adjust)
    "Convert :icon declaration to icon"
    (let* ((icon-set (intern (concat "all-the-icons-" (or set "faicon"))))
           (v-adjust (or v-adjust 0.02))
           (height (or height 0.8))
           (icon (if colour
                     (apply icon-set `(,name :face ,(intern (concat "all-the-icons-" colour)) :height ,height :v-adjust ,v-adjust))
                   (apply icon-set `(,name  :height ,height :v-adjust ,v-adjust))))
           (icon-width (+get-string-width icon))
           (space-width (+get-string-width " "))
           (space-factor (- 2 (/ (float icon-width) space-width))))
      (concat (propertize " " 'display `(space . (:width ,space-factor))) icon)))

  ;; Set up all the fancy icons
  (defun mu4e~initialise-icons ()
    (setq mu4e-use-fancy-chars t
          mu4e-headers-draft-mark      (cons "D" (mu4e~normalised-icon "pencil"))
          mu4e-headers-flagged-mark    (cons "F" (mu4e~normalised-icon "flag"))
          mu4e-headers-new-mark        (cons "N" (mu4e~normalised-icon "sync" :set "material" :height 0.8 :v-adjust -0.10))
          mu4e-headers-passed-mark     (cons "P" (mu4e~normalised-icon "arrow-right"))
          mu4e-headers-replied-mark    (cons "R" (mu4e~normalised-icon "arrow-right"))
          mu4e-headers-seen-mark       (cons "S" "") ;(mu4e~normalised-icon "eye" :height 0.6 :v-adjust 0.07 :colour "dsilver"))
          mu4e-headers-trashed-mark    (cons "T" (mu4e~normalised-icon "trash"))
          mu4e-headers-attach-mark     (cons "a" (mu4e~normalised-icon "file-text-o" :colour "silver"))
          mu4e-headers-encrypted-mark  (cons "x" (mu4e~normalised-icon "lock"))
          mu4e-headers-signed-mark     (cons "s" (mu4e~normalised-icon "certificate" :height 0.7 :colour "dpurple"))
          mu4e-headers-unread-mark     (cons "u" (mu4e~normalised-icon "eye-slash" :v-adjust 0.05))))

  ;; Set the icons only when a graphical frame has been created
  (if (display-graphic-p)
      (mu4e~initialise-icons)
    ;; When it's the server, wait till the first graphical frame
    (add-hook! 'server-after-make-frame-hook
      (defun mu4e~initialise-icons-hook ()
        (when (display-graphic-p)
          (mu4e~initialise-icons)
          (remove-hook #'mu4e~initialise-icons-hook)))))

  (setq mu4e-headers-fields
        '((:account . 12)
          (:human-date . 8)
          (:flags . 6) ; 3 icon flags
          (:from . 25)
          (:subject))

        (plist-put (cdr (assoc :flags mu4e-header-info)) :shortname " Flags") ; default=Flgs

  ;; Add a column to display what email account the email belongs to.
  (add-to-list 'mu4e-header-info-custom
               '(:account
                 :name "Account"
                 :shortname "Account"
                 :help "Which account this email belongs to"
                 :function
                 (lambda (msg)
                   (let ((maildir (mu4e-message-field msg :maildir)))
                     (format "%s" (substring maildir 1 (string-match-p "/" maildir 1)))))))

  (defadvice! +mu4e--refresh-current-view-a (&rest _)
    :after #'mu4e-mark-execute-all (mu4e-headers-rerun-search))

  ;; Wrap text in messages
  (setq-hook! 'mu4e-view-mode-hook truncate-lines nil)

  ;; Html mails might be better rendered in a browser
  (add-to-list 'mu4e-view-actions '("View in browser" . mu4e-action-view-in-browser))

  (when (fboundp 'imagemagick-register-types)
    (imagemagick-register-types))

  (map! :localleader
        :map mu4e-compose-mode-map
        :desc "send and exit" "s" #'message-send-and-exit
        :desc "kill buffer"   "d" #'message-kill-buffer
        :desc "save draft"    "S" #'message-dont-send
        :desc "attach"        "a" #'mail-add-attachment))

(when (featurep! :lang org)
  (use-package! org-msg
    :hook (org-load . org-msg-mode)
    :config
    (setq org-msg-startup "inlineimages"
          org-msg-greeting-name-limit 3
          org-msg-text-plain-alternative t)))



;;
;;; Gmail integration

(when (featurep! +gmail)
  (after! mu4e
    ;; don't save message to Sent Messages, Gmail/IMAP takes care of this
    (setq mu4e-sent-messages-behavior 'delete

          ;; don't need to run cleanup after indexing for gmail
          mu4e-index-cleanup nil

          ;; because gmail uses labels as folders we can use lazy check since
          ;; messages don't really "move"
          mu4e-index-lazy-check t)

    ;; In my workflow, emails won't be moved at all. Only their flags/labels are
    ;; changed. Se we redefine the trash and refile marks not to do any moving.
    ;; However, the real magic happens in `+mu4e|gmail-fix-flags'.
    ;;
    ;; Gmail will handle the rest.
    (defun +mu4e--mark-seen (docid _msg target)
      (mu4e~proc-move docid (mu4e~mark-check-target target) "+S-u-N"))

    (delq! 'delete mu4e-marks #'assq)
    (setf (alist-get 'trash mu4e-marks)
          (list :char '("d" . "▼")
                :prompt "dtrash"
                :dyn-target (lambda (_target msg) (mu4e-get-trash-folder msg))
                :action #'+mu4e--mark-seen)
          ;; Refile will be my "archive" function.
          (alist-get 'refile mu4e-marks)
          (list :char '("r" . "▼")
                :prompt "rrefile"
                :dyn-target (lambda (_target msg) (mu4e-get-refile-folder msg))
                :action #'+mu4e--mark-seen))

    ;; This hook correctly modifies gmail flags on emails when they are marked.
    ;; Without it, refiling (archiving), trashing, and flagging (starring) email
    ;; won't properly result in the corresponding gmail action, since the marks
    ;; are ineffectual otherwise.
    (add-hook! 'mu4e-mark-execute-pre-hook
      (defun +mu4e-gmail-fix-flags-h (mark msg)
        (pcase mark
          (`trash  (mu4e-action-retag-message msg "-\\Inbox,+\\Trash,-\\Draft"))
          (`refile (mu4e-action-retag-message msg "-\\Inbox"))
          (`flag   (mu4e-action-retag-message msg "+\\Starred"))
          (`unflag (mu4e-action-retag-message msg "-\\Starred")))))))
