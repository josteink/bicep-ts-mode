;;; bicep-ts-mode.el --- tree-sitter support for Bicep  -*- lexical-binding: t; -*-

;; Copyright (C) 2023-2025 Free Software Foundation, Inc.

;; Author     : Jostein Kjønigsen <jostein@kjonigsen.net>
;; Maintainer : Jostein Kjønigsen <jostein@kjonigsen.net>
;; Created    : December 2023
;; Keywords   : bicep languages tree-sitter
;; Version    : 0.1.4
;; X-URL      : https://github.com/josteink/bicep-ts-mode

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;

;;; Code:

(require 'treesit)
(require 'json)
(require 'url)

(declare-function treesit-parser-create "treesit.c")
(declare-function treesit-induce-sparse-tree "treesit.c")
(declare-function treesit-node-start "treesit.c")
(declare-function treesit-node-type "treesit.c")
(declare-function treesit-node-child "treesit.c")
(declare-function treesit-node-child-by-field-name "treesit.c")

(defgroup bicep nil
  "Major-mode for editing Bicep-files."
  :group 'languages)

(defcustom bicep-ts-mode-indent-offset 2
  "Number of spaces for each indentation step in `bicep-ts-mode'."
  :type 'natnum
  :safe #'natnump)

(defcustom bicep-ts-mode-enforce-quotes t
  "Makes bicep-ts-mode enforce the correct kind of quote when creating strings.
Changes may require an Emacs-restart to take effect."
  :type 'boolean
  :safe #'booleanp)

(defcustom bicep-ts-mode-default-langserver-path
  (expand-file-name ".cache/bicep/Bicep.LangServer.dll" user-emacs-directory)
  "Default expression used to locate Bicep Languageserver.
If found, added to eglot.  Supports environment-variables and glob-pattterns.
Changes may require an Emacs-restart to take effect."
  :type 'string)

(defvar bicep-ts-mode--syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?=  "."    table)
    (modify-syntax-entry ?:  "."    table)
    (modify-syntax-entry ?\" "."    table)  ;; Double quote as punctuation
    (modify-syntax-entry ?'  "\""   table)  ;; Single quote as string-delimiter
    (modify-syntax-entry ?\\ "\\"   table)  ;; Backslash as escape character
    (modify-syntax-entry ?/  ". 12" table)  ;; Define `//` as a comment starter
    (modify-syntax-entry ?\n ">"    table)  ;; Newline ends comments
    table)
  "Syntax table for `bicep-ts-mode'.")

(defvar bicep-ts-mode--indent-rules
  `((bicep
     ((node-is "}") parent-bol 0)
     ((node-is "]") parent-bol 0)
     ((parent-is "array") parent-bol bicep-ts-mode-indent-offset)
     ((parent-is "object") parent-bol bicep-ts-mode-indent-offset)
     ((parent-is "for_statement") parent-bol bicep-ts-mode-indent-offset)
     ((parent-is "arguments") parent-bol bicep-ts-mode-indent-offset)
     ((parent-is "variable_declaration") parent-bol bicep-ts-mode-indent-offset)
     ((parent-is "ternary_expression") parent-bol bicep-ts-mode-indent-offset)
     )))

(defvar bicep-ts-mode--keywords
  '("var" "param" "resource" "func"
    "module" "type" "metadata"
    "targetScope" "output"
    "for" "in" "using" "existing" "if")
  "Bicep keywords for tree-sitter font-locking.")

(defvar bicep-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :language 'bicep
   :feature 'comment
   '((comment) @font-lock-comment-face
     ((identifier) @font-lock-constant-face
      (:equal "az" @font-lock-constant-face)))

   :language 'bicep
   :feature 'delimiter
   '(("=") @font-lock-operator-face)

   :language 'bicep
   :feature 'keyword
   `([,@bicep-ts-mode--keywords] @font-lock-keyword-face)

   :language 'bicep
   :feature 'definition
   '((type) @font-lock-type-face
     (resource_declaration
      (string
       (string_content) @font-lock-type-face))
     (parameter_declaration
      (identifier) @font-lock-variable-name-face)
     (variable_declaration
      (identifier) @font-lock-variable-name-face)
     (resource_declaration
      (identifier) @font-lock-variable-name-face)
     (user_defined_function
      (identifier) @font-lock-function-name-face)
     (parameter
      (identifier) @font-lock-variable-name-face)
     (module_declaration
      (identifier) @font-lock-variable-name-face)
     (for_statement
      initializer: (identifier) @font-lock-variable-name-face)
     (for_statement
      (identifier) @font-lock-variable-use-face)
     (output_declaration
      (identifier) @font-lock-variable-name-face)
     (object_property
      (identifier) @font-lock-property-name-face
      ":"
      (identifier) @font-lock-variable-use-face)
     (object_property
      (identifier) @font-lock-property-name-face
      ":"
      [(array) (string) (number) (boolean) (object) (member_expression) (call_expression)
       (for_statement) (ternary_expression)])
     (interpolation
      (identifier) @font-lock-variable-use-face)
     (arguments
      (identifier) @font-lock-variable-use-face)
     (member_expression
      object: (identifier) @font-lock-variable-use-face)
     (property_identifier) @font-lock-property-use-face
     (if_statement
      (parenthesized_expression
       (identifier) @font-lock-variable-use-face))
     (binary_expression
      (identifier) @font-lock-variable-use-face)
     (array
      (identifier) @font-lock-variable-use-face)
     (subscript_expression
      object: (identifier) @font-lock-variable-use-face
      index: (identifier) @font-lock-variable-use-face)
     (ternary_expression
      condition: (identifier) @font-lock-variable-use-face))

   :language 'bicep
   :feature 'number
   '((number)
     @font-lock-number-face)

   :language 'bicep
   :feature 'string
   '((string_content) @font-lock-string-face
     (interpolation
      ["${" "}"] @font-lock-misc-punctuation-face)
     (escape_sequence) @font-lock-escape-face)

   :language 'bicep
   :feature 'boolean
   '((boolean) @font-lock-constant-face)

   :language 'bicep
   :feature 'functions
   :override t ;; required to override property-use-face in other member-expressions!
   '(
     (call_expression
      function: (identifier) @font-lock-function-call-face)
     (call_expression
      function: (member_expression
                 property: (property_identifier) @font-lock-function-call-face)))

   :language 'bicep
   :feature 'error
   :override t
   '((ERROR) @font-lock-warning-face))
  "Font-lock settings for BICEP.")

(defun bicep--fetch-json-array (url)
  "Fetch JSON from URL, skip headers, and parse buffer as JSON array.
Return the parsed JSON array."
  (with-current-buffer (url-retrieve-synchronously url t)
    (goto-char (point-min))
    (re-search-forward "\n\n")  ;; Skip headers
    (let* ((json-array (json-parse-buffer :array-type 'list)))
      json-array)))

(defun bicep--unzip-file (zip-file destination)
  "Unzip ZIP-FILE into DESTINATION directory using the 'unzip' shell command.
Creates DESTINATION directory if it doesn't exist."
  (unless (file-directory-p destination)
    (make-directory destination :parents))  ;; Ensure the destination directory exists
  (let ((exit-code (call-process "unzip" nil nil nil "-o" zip-file "-d" destination)))
    (if (zerop exit-code)
        (message "Successfully unzipped %s to %s" zip-file destination)
      (error "Failed to unzip %s (exit code %d)" zip-file exit-code))))

(defun bicep--get-latest-release-version ()
  "Get the latest release version tag name for Azure Bicep from GitHub API.
Assumes the first release in the fetched list is the latest."
  (let* ((release-json (bicep--fetch-json-array "https://api.github.com/repos/Azure/bicep/releases"))
         (first        (car release-json)) ;; assume first = latest
         (version      (gethash "tag_name" first)))
    version))

(defun bicep--download-langserver ()
  "Download and unpack the Bicep language server.
Determines download URL from the latest release version, downloads the zip,
unpacks it, and deletes the downloaded zip file."
  (let* ((bicep-dir (expand-file-name ".cache/bicep" user-emacs-directory))
         (download-dir  (expand-file-name "dl" bicep-dir))
         (download-file (expand-file-name "bicep-langserver.zip" download-dir)))
    (make-directory bicep-dir :parents)
    (make-directory download-dir :parents)
    (let* ((version     (bicep--get-latest-release-version))
           (url         (format "https://github.com/Azure/bicep/releases/download/%s/bicep-langserver.zip" version)))
      (url-copy-file url download-file 't)
      (bicep--unzip-file download-file bicep-dir)
      (delete-directory download-dir t)
      ;; make our function respond with something more interesting than nil :)
      (message (format "Bicep LangServer version %s downloaded and unpacked to \'%s\'" version bicep-dir)))))

(defun bicep-install-langserver ()
  "Downloads the lang-server and unpacks it in the default location."
  (interactive)
  (bicep--download-langserver)
  (bicep--register-langserver))

(defun bicep--register-langserver ()
  "Register the Bicep language server with eglot if server path exists.
Adds `bicep-ts-mode` and server program to `eglot-server-programs`."
  (defvar eglot-server-programs)
  (and (file-exists-p (bicep-langserver-path))
       (add-to-list 'eglot-server-programs
                    `(bicep-ts-mode . ("dotnet" ,(bicep-langserver-path))))))


(defun bicep-langserver-path ()
  "Return the path to the Bicep language server DLL.
Expands wildcards and substitutes in the file name from
`bicep-ts-mode-default-langserver-path`."
  ;; Note: In GNU land, we call this a file name, not a path.
  (car (file-expand-wildcards
        (substitute-in-file-name bicep-ts-mode-default-langserver-path))))

(defun bicep-ts-mode--defun-name (node)
  "Return the defun name of NODE.
Return nil if there is no name or if NODE is not a defun node."
  (let ((defun-node (bicep-ts-mode--find-declaration-node node)))
    (when defun-node
      (treesit-node-text
       (treesit-node-child defun-node 1)
       t))))

;; required due to named-let.
(eval-when-compile (require 'subr-x))
(defun bicep-ts-mode--find-declaration-node (node)
  "Search up the tree from NODE for a node whose type contains `declaration'.
Return the first matching node, or nil if none is found."

  ;; Recursion is elegant, but ELisp's implementation handles
  ;; it rather poorly, so it's best avoided when not too hard.
  ;; Instead use  `named-let', which does TCO?
  ;; NOTE: requires subr-x.
  (named-let loop ((node node))
    (when node
      (if (string-match-p "declaration" (treesit-node-type node))
          node
        (loop (treesit-node-parent node))))))

;;;###autoload
(define-derived-mode bicep-ts-mode prog-mode "Bicep"
  "Major mode for editing BICEP, powered by tree-sitter."
  :syntax-table bicep-ts-mode--syntax-table

  (if (not (treesit-ready-p 'bicep))
      (message "Please run `M-x treesit-install-language-grammar RET bicep'")
    (setq treesit-primary-parser (treesit-parser-create 'bicep))

    ;; Comments
    (setq-local comment-start "// ")
    (setq-local comment-start-skip "//+\\s-*")
    (setq-local comment-end "")

    ;; Indent.
    (setq-local treesit-simple-indent-rules bicep-ts-mode--indent-rules)

    ;; Navigation.
    (setq-local treesit-defun-type-regexp
                (rx (or "module_declaration" "type_declaration" "variable_declaration"
                        "parameter_declaration" "resource_declaration" "output_declaration"
                        "function_declaration")))
    (setq-local treesit-defun-name-function #'bicep-ts-mode--defun-name)

    ;; Font-lock.
    (setq-local treesit-font-lock-settings bicep-ts-mode--font-lock-settings)
    (setq-local treesit-font-lock-feature-list
                '((comment delimiter keyword)
                  (definition number string boolean)
                  (functions)
                  (error)))

    ;; Imenu.
    (setq-local treesit-simple-imenu-settings
                '(("Modules" "\\`module_declaration\\'" nil nil)
                  ("Functions" "\\`user_defined_function\\'" nil nil)
                  ("Types" "\\`type_declaration\\'" nil nil)
                  ("Parameters" "\\`parameter_declaration\\'" nil nil)
                  ("Variables" "\\`variable_declaration\\'" nil nil)
                  ("Resources" "\\`resource_declaration\\'" nil nil)
                  ("Outputs" "\\`output_declaration\\'" nil nil)))

    (treesit-major-mode-setup)))

;; quote management

(defun bicep--insert-single-quote-dwim ()
  "Intelligently insert a single quote.
If inside an unterminated string, insert a closing single quote.
If inside a terminated string, insert an escaped single quote.
Otherwise, insert a single quote to start a new string."
  (interactive)

  (let* ((state (syntax-ppss))     ;; Get current syntactic state
         (in-string (nth 3 state)) ;; Non-nil if inside a string
         (unterminated (and in-string
                            (save-excursion
                              ;;(goto-char string-start)  ;; Move to string start
                              (not (re-search-forward "'" (line-end-position) t)))))) ;; No closing quote before newline
    (cond
     (unterminated
      (insert "'"))
     (in-string
      (insert "\\'"))
     (t
      (insert "'")))))

(defun bicep--insert-double-quote-dwim ()
  "Intelligently insert a double quote.
If inside an unterminated string (expected to be single-quoted),
insert a closing single quote. If inside a properly terminated string,
allow a double quote. Otherwise, insert a single quote to start a
new string, effectively preferring single quotes for new strings."
  (interactive)

  (let* ((state (syntax-ppss))     ;; Get current syntactic state
         (in-string (nth 3 state)) ;; Non-nil if inside a string
         (unterminated (and in-string
                            (save-excursion
                              ;;(goto-char string-start)  ;; Move to string start
                              (not (re-search-forward "'" (line-end-position) t)))))) ;; No closing quote before newline
    (cond
     ;; If inside an unterminated string, close it
     (unterminated
      (insert "'"))
     ;; If inside a properly terminated string, allow double-quotes
     (in-string
      (insert "\""))
     ;; Otherwise, insert a single-quote to start a new string
     (t
      (insert "'")))))


(when bicep-ts-mode-enforce-quotes
  (define-key bicep-ts-mode-map (kbd "'") #'bicep--insert-single-quote-dwim)
  (define-key bicep-ts-mode-map (kbd "\"") #'bicep--insert-double-quote-dwim))

;; Our treesit-font-lock-rules expect this version of the grammar:
(add-to-list 'treesit-language-source-alist
             '(bicep . ("https://github.com/tree-sitter-grammars/tree-sitter-bicep" "v1.1.0")))

;;;###autoload
(and (fboundp 'treesit-ready-p)
     (treesit-ready-p 'bicep)
     (progn
       (add-to-list 'auto-mode-alist '("\\.bicep\\(param\\)?\\'"
                                       . bicep-ts-mode))))

;;;###autoload
(with-eval-after-load 'eglot
  (bicep--register-langserver))

(provide 'bicep-ts-mode)

;;; bicep-ts-mode.el ends here
