;;; robot-mode.el --- Support for robot framework files

;; Author: Juuso Valkeejärvi <jvalkeejarvi@gmail.com>
;; Version: 1.0
;; Keywords: robot

;; Robot mode

;; ==========

;; A major mode for editing robot framework text files.

;;     This program is free software: you can redistribute it and/or modify
;;     it under the terms of the GNU General Public License as published by
;;     the Free Software Foundation, either version 3 of the License, or
;;     (at your option) any later version.

;;     This program is distributed in the hope that it will be useful,
;;     but WITHOUT ANY WARRANTY; without even the implied warranty of
;;     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;     GNU General Public License for more details.

;;     You should have received a copy of the GNU General Public License
;;     along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;
;; You can participate by sending pull requests to https://github.com/jvalkeejarvi/robot-mode

(require 's)

(defvar robot-keyword-word-separator " " "Character that is used to distinguish words in keywords, underscore or space should be used")
(defvar robot-basic-offset 4 "Defines how many spaces are used for indentation (only used when indent-tabs mode is nil)")

(setq robot-mode-keywords
      (let* (
             (words1 '("..." ":FOR" "AND" "ELSE" "IF" "IN RANGE" "IN"))
             (words2 '("Documentation" "Library" "Resource" "Suite Setup" "Suite Teardown"
                       "Test Timeout" "Variables" "Test Setup" "Test Teardown"))
             (words1-regexp (concat (regexp-opt words1) "\\s-"))
             (words2-regexp (concat "^" (regexp-opt words2 'words)))
             ;; construct regexp for variable face
             (variable-not-allowed-characters "[^ \t{}\\$]")
             (variable-allowed-pattern (format "\\( ?%s\\)*" variable-not-allowed-characters))
             (variable-pattern (format "[@\\$]{%s\\(:?[@\\$]{%s+}\\)?%s}" variable-allowed-pattern
                                       variable-not-allowed-characters variable-allowed-pattern))
             )
        `(
          ;;normal comment
          ("#.*" . font-lock-comment-face)
          ;;FOR, IF etc
          (,words1-regexp . font-lock-type-face)
          ;;Suite setup keywords
          (,words2-regexp . font-lock-builtin-face)
          ;;Section headers
          ("\\*\\*\\* ?[^\\*]+ ?\\*\\*\\*" . font-lock-keyword-face)
          ;;keyword definitions
          ("^[^ \t\n\$]+" . font-lock-function-name-face)
          ;;Variables (use 0 operator with t argument instead of . to allow variable highlighting inside comments)
          ( ,variable-pattern . font-lock-variable-name-face)
          ;;tags etc
          ("\\[[^\]]+\\]+" . font-lock-constant-face)
          ;;comment kw
          ("[Cc]omment\\(  \\|\t\\).*" . font-lock-comment-face)
          )
        ))

(defun robot-indent()
  "Returns the string used in indation.

Set indent-tabs-mode to non-nil to use tabs in indentation. If indent-tabs-mode is 
set to nil robot-basic-offset defines how many spaces are used for indentation.
"
  (if indent-tabs-mode
      "\t"
    (make-string robot-basic-offset ?\ )
    )
  )

(defun robot-keyword-start-point()
  (save-excursion (re-search-backward "^\\|\\(  \\)\\|\t"))
  )

(defun robot-keyword-end-point()
  (save-excursion (re-search-forward "$\\|\\(  \\)\\|\t"))
  )

(defun prefix-is-variable(kw)
  (or (string-prefix-p "@" kw)
      (string-prefix-p "$" kw))
  )

(defun variable-prefix-has-ending-bracket(prefix)
  (string-suffix-p "}" prefix)
  )

(defun variable-prefix-trim(prefix)
  (if (variable-prefix-has-ending-bracket prefix)
      (substring prefix 0 -1)
    prefix
    )
  )

(defun robot-mode-kw-at-point()
  "Return the robot keyword (or possibly infix variable) around the current point in buffer"
  (defun extract-kw (str)
    (defun trim (str)
      (s-trim-left (replace-regexp-in-string "\\(^\s+\\)\\|\n$" "" str)))
    (defun cut-kw (str)
      (replace-regexp-in-string "\\(  \\|\t\\).*$" "" str))
    (defun cut-bdd (str) 
      (replace-regexp-in-string "^\\(given\\)\\|\\(then\\)\\|\\(when\\)\\s*" "" str))
    (cut-kw (cut-bdd (trim str)))
    )
  (let* ((kw-end (robot-keyword-end-point))
         (kw-start (robot-keyword-start-point))
	 )
    (save-excursion 
      (let* ((variable-end (re-search-forward "[^}]*}" kw-end t))
	     (variable-start (re-search-backward "\\(\\$\\|@\\){[^{]*" kw-start t)))
	(if (and variable-end variable-start) 
	    (buffer-substring variable-start variable-end)
	  (extract-kw (buffer-substring kw-start kw-end))
	  )
	)
      )
    )
  )

(defun robot-mode-continue-find-kw()
  "Find the next matching robot kw."
  (interactive)
  (find-tag-regexp "" t)
  )

(defun robot-mode-make-kw-regexp(kw)
  (defun match-underscores (str)
    (replace-regexp-in-string "\\(_\\| \\)" "[_ ]?" str t t))
  (defun match-infix-args (str)
    (replace-regexp-in-string "'[^']+'" "'\\($\\|@\\){[^}]+}'" str t t))
  (match-infix-args (match-underscores kw))
)

(defun robot-mode-find-first-kw()
  "Start the robot kw search."
  (setq default-kw (if (and transient-mark-mode mark-active)
			  (buffer-substring-no-properties (region-beginning) (region-end))
			(robot-mode-kw-at-point)
			))
  (let ((kw (read-from-minibuffer (format "Find kw (%s): " default-kw))))
    (if (string= "" kw) (find-tag-regexp (robot-mode-make-kw-regexp default-kw))
      (find-tag-regexp (robot-mode-make-kw-regexp kw)) 
      )
    )
  )

(defun robot-mode-complete(kw-prefix)
  "Complete the symbol before point.

\\<robot-mode-map>
This function is bound to \\[robot-mode-complete].
"
  (interactive (list (robot-mode-kw-at-point)))
  (let ((kw-regexp (robot-mode-make-kw-regexp (variable-prefix-trim kw-prefix))))
    (defun normalize-candidate-kw(kw prefix) 
      (defun capitalize-first-character(kw)
        "Capitalize first character of a word, don't affect rest of string"
        (when (and kw (> (length kw) 0))
          (let ((first-char (substring kw 0 1))
                (rest-str   (substring kw 1)))
            (concat (capitalize first-char) rest-str)))
        )
      ;; Check whether kw candidate is a keyword or a variable
      (if (prefix-is-variable kw)
          ;; If is variable, delete closing bracket from candidate if it already exists in prefix
          (if (variable-prefix-has-ending-bracket prefix)
              (variable-prefix-trim kw)
            kw
            )
        (let ((word-separator (if (string-match-p "_" kw-prefix)
                                 "_"
                               (if (string-match-p " " kw-prefix)
                                   " "
                                 robot-keyword-word-separator))))
          ;; If is keyword split to words, capitalize and join words with defined character
          (s-join word-separator (mapcar 'capitalize-first-character (s-split-words kw)))
          )
        )
      )
    (let ((possible-completions ()))
      (let ((enable-recursive-minibuffers t)
	    (pick-next-buffer nil)
	    (kw-full (format "^\\s-*\\(def +\\)?\\(%s[^\177\n]*?\\)(?\177\\(\\(.+\\)\\)?" kw-regexp)))
	(save-excursion
	  (visit-tags-table-buffer pick-next-buffer)
	  (set 'pick-next-buffer t)
	  (goto-char (point-min))
	  (while (re-search-forward kw-full nil t)
	    (if (or (match-beginning 2) (match-beginning 4))
		(let ((got (buffer-substring 
			    (or (match-beginning 4) (match-beginning 2)) 
			    (or (match-end 4) (match-end 2)))))
		  (add-to-list 'possible-completions (normalize-candidate-kw got kw-prefix))
		  )
	      )
	    )
	  )
	)
      (cond ((not possible-completions) (message "No completions found!"))
	    (t
       (let* ((kw-end (robot-keyword-end-point))
              (kw-start (robot-keyword-start-point))
              (completion-ignore-case t)
              ;; Decrement kw-end by one if completion is variable and prefix already has closing bracket
              (kw-end (if (variable-prefix-has-ending-bracket kw-prefix)
                          (- kw-end 1)
                        kw-end))
              )
         (completion-in-region (+ kw-start 1) kw-end possible-completions))
         )
	    )
      )
    )
  )

(defun robot-mode-find-kw(continue)
  "Find the kw in region or in the line where the point is from TAGS.

If 'continue' is is non nil or interactively if the function is called
with a prefix argument (i.e. prefixed with \\[universal-argument]) then continue from the last
found kw.

\\<robot-mode-map>
This function is bound to \\[robot-mode-find-kw].
"
  (interactive "P")
  (if continue (robot-mode-continue-find-kw)
    (robot-mode-find-first-kw)
    )
  )

(defun robot-mode-newline()
"Do the right thing when inserting newline.

\\<robot-mode-map>
This function is bound to \\[robot-mode-newline].
"
(interactive)

(defun inside-kw-definition() 
  (save-excursion
    (beginning-of-line)
    (re-search-forward "[^ \t]" (line-end-position) t)
    )
  )

(defun remove-possible-empty-tab()
  (save-excursion
    (beginning-of-line)
    (let ((line (delete-and-extract-region (line-beginning-position) (line-end-position)))
	  )
      (insert (replace-regexp-in-string "^[ \t]+$" "" line))
      )
    )
  )

(if (inside-kw-definition) (insert (concat "\n" (robot-indent)))
  (remove-possible-empty-tab)
  (insert "\n")
  )
)

(defun robot-mode-indent-region()
"Fix indentation in the region.

\\<robot-mode-map>
This function is bound to \\[robot-mode-newline].
"
(interactive)
(save-excursion
  (let* ((region (delete-and-extract-region (region-beginning) (region-end) ))
	 (fixed-region (replace-regexp-in-string "^[ \t]+" (robot-indent) region))
	 )
    (insert fixed-region)
    )
  )
)

(defun robot-mode-indent()
"Switch between indent and unindent in robot mode.

\\<robot-mode-map>
This function is bound to \\[robot-mode-indent].
"
(interactive)
(save-excursion
  (beginning-of-line)
  (let ((line (delete-and-extract-region (line-beginning-position) (line-end-position)))
	) 
    (if (string-match "^[ \t]+" line)
	(insert (replace-regexp-in-string "^[ \t]+" "" line))
      (insert (concat (robot-indent) line))
      )
    )
  )
)

(define-derived-mode robot-mode prog-mode
  "robot mode"
  "Major mode for editing Robot Framework text files.

This mode rebinds the following keys to new function:
\\{robot-mode-map}
In the table above <remap> <function> means that the function is bound to whatever 
key <function> was bound previously. To see the actual key binding press enter on
top of the bound function. 

You can use \\[beginning-of-defun] to move to the beginning of the kw 
the cursor point is at and \\[end-of-defun] to move to the end of the kw. 
To select (i.e. put a region around) the whole kw definition press \\[mark-defun].
 
Set indent-tabs-mode to non-nil to use tabs for indantation. If indent-tabs-mode is nil, 
robot-basic-offset defines the amount of spaces that are inserted when indenting.
"
  (require 'etags)
  (setq font-lock-defaults '((robot-mode-keywords)))

  (set (make-local-variable 'comment-start) "#")
  (set (make-local-variable 'comment-start-skip) "#")

  (set (make-local-variable 'beginning-of-defun-function) (lambda()
							    (re-search-backward "^[^ \t\n]")
							    )
       )
  (set (make-local-variable 'end-of-defun-function) (lambda() 
						      (end-of-line)
						      (if (not (re-search-forward "^[^ \t\n]" nil t))
							  (goto-char (point-max))
							(beginning-of-line)
							)
						      )
       )


  (define-key robot-mode-map (kbd "TAB") 'robot-mode-indent)
  (define-key robot-mode-map (kbd "RET") 'robot-mode-newline)
  (define-key robot-mode-map [remap find-tag] 'robot-mode-find-kw)
  (define-key robot-mode-map [remap complete-symbol] 'robot-mode-complete)
  (define-key robot-mode-map [remap indent-region] 'robot-mode-indent-region)
  )
   
(add-to-list 'auto-mode-alist '("\\.robot\\'" . robot-mode))

(provide 'robot-mode)
;;; robot-mode.el ends here
