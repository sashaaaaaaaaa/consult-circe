;;; consult-circe.el --- Consult interface for Circe IRC buffers -*- lexical-binding: t -*-

;; Original work Copyright (C) 2015 Les Harris <les@lesharris.com>
;; Modified work Copyright (C) 2026 Sasha Abbott <sashaa@disroot.org>

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;; Author: Sasha Abbott <sashaa@disroot.org>
;; URL: https://github.com/sashaaaaaaaaa/consult-circe
;; Version: 0.2
;; Package-Requires: ((emacs "27.1") (consult "3.3") (circe "2.14"))
;; Keywords: comm

;;; Commentary:

;; Jump to Circe buffers with Consult.
;;
;; Based on helm-circe by Les Harris <les@lesharris.com>
;; (https://github.com/lesharris/helm-circe).
;;
;; Each candidate is annotated with its type
;; (channel, server, query) and its parent server name.
;;
;; Embark integration provides actions on candidates while the minibuffer
;; is open.  Use `embark-act' (bound to C-, by default) on any candidate:
;;
;;   RET / s   switch to buffer
;;   k         kill/part buffer
;;
;; For ibuffer-style mark-and-delete, use `embark-act' then `E' to run
;; `embark-export', which opens the candidates in an Ibuffer buffer where
;; you can mark and kill buffers with the usual ibuffer commands.
;;
;; Entry points:
;;
;;   `consult-circe'              — channels + queries + servers
;;   `consult-circe-new-activity' — buffers with recent tracking activity
;;   `consult-circe-by-server'    — channels grouped by server
;;   `consult-circe-channels'     — channels only
;;   `consult-circe-servers'      — servers only
;;   `consult-circe-queries'      — queries only
;;   `consult-circe-kill-buffer'  — standalone kill/part command

;;; Code:

(require 'consult)
(require 'circe)

;;; ---------------------------------------------------------------------------
;;; Buffer collection helpers
;;; ---------------------------------------------------------------------------

(defun consult-circe--buffers-by-mode (mode)
  "Return names of all live buffers whose major-mode is MODE."
  (mapcar #'buffer-name
          (seq-filter (lambda (buf)
                        (eq mode (buffer-local-value 'major-mode buf)))
                      (buffer-list))))

(defun consult-circe--channel-buffers ()
  "Return circe channel buffer names."
  (consult-circe--buffers-by-mode 'circe-channel-mode))

(defun consult-circe--server-buffers ()
  "Return circe server buffer names."
  (consult-circe--buffers-by-mode 'circe-server-mode))

(defun consult-circe--query-buffers ()
  "Return circe query buffer names."
  (consult-circe--buffers-by-mode 'circe-query-mode))

(defun consult-circe--recent-buffers ()
  "Return circe buffers with unread tracking activity."
  (mapcar (lambda (b) (if (bufferp b) (buffer-name b) b))
          (bound-and-true-p tracking-buffers)))

(defun consult-circe--all-buffers ()
  "Return all circe buffer names."
  (append (consult-circe--channel-buffers)
          (consult-circe--query-buffers)
          (consult-circe--server-buffers)))

;;; ---------------------------------------------------------------------------
;;; Faces
;;; ---------------------------------------------------------------------------

(defface consult-circe-buffer-face
  '((t :inherit consult-buffer))
  "Face for circe buffer (channel, server, query) names.")

(defface consult-circe-type-face
  '((t :inherit help-key-binding))
  "Face for the buffer type annotation (channel, server, query).")

(defface consult-circe-server-face
  '((t :inherit font-lock-comment-face))
  "Face for the parent server name annotation.")

;;; ---------------------------------------------------------------------------
;;; Annotation
;;; ---------------------------------------------------------------------------

(defun consult-circe--annotate (candidate)
  "Return an annotation string for the circe buffer named CANDIDATE."
  (when-let* ((buf  (get-buffer candidate))
              (mode (buffer-local-value 'major-mode buf)))
    (let* ((type (pcase mode
                   ('circe-channel-mode "channel")
                   ('circe-server-mode  "server")
                   ('circe-query-mode   "query")
                   (_                   "circe")))
           (server-buf (buffer-local-value 'circe-server-buffer buf))
           (server     (when (and server-buf (buffer-live-p server-buf))
                         (buffer-name server-buf))))
      (concat " "
              (propertize (format "%-7s" type) 'face 'consult-circe-type-face)
              (when server
                (concat "  "
                        (propertize server 'face 'consult-circe-server-face)))))))

;;; ---------------------------------------------------------------------------
;;; consult--source plists
;;; ---------------------------------------------------------------------------

(defvar consult-circe--source-channels
  `(:name      "Channels"
    :category  circe-buffer
    :face      consult-circe-buffer-face
    :annotate  ,#'consult-circe--annotate
    :items     ,#'consult-circe--channel-buffers
    :action    ,(lambda (buf) (switch-to-buffer buf)))
  "Consult source for circe channel buffers.")

(defvar consult-circe--source-queries
  `(:name      "Queries"
    :category  circe-buffer
    :face      consult-circe-buffer-face
    :annotate  ,#'consult-circe--annotate
    :items     ,#'consult-circe--query-buffers
    :action    ,(lambda (buf) (switch-to-buffer buf)))
  "Consult source for circe query buffers.")

(defvar consult-circe--source-servers
  `(:name      "Servers"
    :category  circe-buffer
    :face      consult-circe-buffer-face
    :annotate  ,#'consult-circe--annotate
    :items     ,#'consult-circe--server-buffers
    :action    ,(lambda (buf) (switch-to-buffer buf)))
  "Consult source for circe server buffers.")

(defvar consult-circe--source-new-activity
  `(:name      "New Activity"
    :category  circe-buffer
    :annotate  ,#'consult-circe--annotate
    :items     ,#'consult-circe--recent-buffers
    :action    ,(lambda (buf) (switch-to-buffer buf)))
  "Consult source for circe buffers with recent activity.")

;;; ---------------------------------------------------------------------------
;;; Embark integration (optional)
;;; ---------------------------------------------------------------------------

(defun consult-circe--kill-buffer (candidate)
  "Kill the circe buffer named CANDIDATE."
  (when-let ((buf (get-buffer candidate)))
    (kill-buffer buf)
    (message "Killed %s" candidate)))

(with-eval-after-load 'embark
  (defvar consult-circe-embark-actions
    (let ((map (make-sparse-keymap)))
      (set-keymap-parent map embark-general-map)
        (define-key map "s" #'switch-to-buffer)
      (define-key map "k" #'consult-circe--kill-buffer)
      map)
    "Keymap of Embark actions for circe buffer candidates.")

  (setf (alist-get 'circe-buffer embark-keymap-alist)
        'consult-circe-embark-actions)

  (setf (alist-get 'circe-buffer embark-default-action-overrides)
        #'switch-to-buffer)

  (setf (alist-get 'circe-buffer embark-exporters-alist)
        #'embark-export-ibuffer))

;;; ---------------------------------------------------------------------------
;;; Kill command
;;; ---------------------------------------------------------------------------

;;;###autoload
(defun consult-circe-kill-buffer ()
  "Interactively select and kill a circe buffer (part/disconnect/close)."
  (interactive)
  (let ((bufs (consult-circe--all-buffers)))
    (if bufs
        (let ((choice (completing-read "Kill circe buffer: " bufs nil t)))
          (when-let ((buf (get-buffer choice)))
            (kill-buffer buf)
            (message "Killed %s" choice)))
      (message "No circe buffers."))))

;;; ---------------------------------------------------------------------------
;;; By-server grouping
;;; ---------------------------------------------------------------------------

(defun consult-circe--sources-by-server ()
  "Return a list of consult sources, one per connected server."
  (mapcar
   (lambda (server-name)
     (with-current-buffer server-name
       (let ((bufs (mapcar #'buffer-name (circe-server-chat-buffers))))
         `(:name     ,server-name
           :category circe-buffer
           :annotate ,#'consult-circe--annotate
           :items    ,(lambda () bufs)
           :action   ,(lambda (buf) (switch-to-buffer buf))))))
   (seq-filter #'get-buffer (consult-circe--server-buffers))))

;;; ---------------------------------------------------------------------------
;;; Public entry points
;;; ---------------------------------------------------------------------------

;;;###autoload
(defun consult-circe ()
  "Switch to a circe channel, query, or server buffer.
Candidates are grouped by type (Channels / Queries / Servers)."
  (interactive)
  (if (consult-circe--all-buffers)
      (consult--multi '(consult-circe--source-channels
                        consult-circe--source-queries
                        consult-circe--source-servers)
                      :prompt "Circe: "
                      :require-match t
                      :sort nil)
    (message "No circe buffers.")))

;;;###autoload
(defun consult-circe-new-activity ()
  "Switch to a circe buffer that has new unread activity."
  (interactive)
  (if (consult-circe--recent-buffers)
      (consult--multi '(consult-circe--source-new-activity)
                      :prompt "New activity: "
                      :require-match t
                      :sort nil)
    (message "No circe buffers with new activity.")))

;;;###autoload
(defun consult-circe-by-server ()
  "Switch to a circe channel, with candidates grouped by server."
  (interactive)
  (let ((sources (consult-circe--sources-by-server)))
    (if sources
        (consult--multi sources
                        :prompt "Server → channel: "
                        :require-match t
                        :sort nil)
      (message "No circe servers connected."))))

;;;###autoload
(defun consult-circe-channels ()
  "Switch to a circe channel buffer."
  (interactive)
  (if (consult-circe--channel-buffers)
      (consult--multi '(consult-circe--source-channels)
                      :prompt "Channel: "
                      :require-match t
                      :sort nil)
    (message "No circe channel buffers.")))

;;;###autoload
(defun consult-circe-servers ()
  "Switch to a circe server buffer."
  (interactive)
  (if (consult-circe--server-buffers)
      (consult--multi '(consult-circe--source-servers)
                      :prompt "Server: "
                      :require-match t
                      :sort nil)
    (message "No circe server buffers.")))

;;;###autoload
(defun consult-circe-queries ()
  "Switch to a circe query buffer."
  (interactive)
  (if (consult-circe--query-buffers)
      (consult--multi '(consult-circe--source-queries)
                      :prompt "Query: "
                      :require-match t
                      :sort nil)
    (message "No circe query buffers.")))

(provide 'consult-circe)

;;; consult-circe.el ends here
