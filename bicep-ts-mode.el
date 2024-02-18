;;; bicep-ts-mode.el --- tree-sitter support for Bicep  -*- lexical-binding: t; -*-

;; Copyright (C) 2023-2024 Free Software Foundation, Inc.

;; Author     : Jostein Kjønigsen <jostein@kjonigsen.net>
;; Maintainer : Jostein Kjønigsen <jostein@kjonigsen.net>
;; Created    : December 2023
;; Keywords   : bicep languages tree-sitter
;; Version    : 0.1.3
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

(declare-function treesit-parser-create "treesit.c")
(declare-function treesit-induce-sparse-tree "treesit.c")
(declare-function treesit-node-start "treesit.c")
(declare-function treesit-node-type "treesit.c")
(declare-function treesit-node-child "treesit.c")
(declare-function treesit-node-child-by-field-name "treesit.c")

(defgroup bicep nil
  "Major-mode for editing Bicep-files"
  :group 'languages)

(defcustom bicep-ts-mode-indent-offset 2
  "Number of spaces for each indentation step in `bicep-ts-mode'."
  :type 'natnum
  :safe 'natnump
  :group 'bicep)

(defvar bicep-ts-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?=  "."   table)
    (modify-syntax-entry ?\' "\""  table)
    (modify-syntax-entry ?\n "> b" table)
    table)
  "Syntax table for `bicep-ts-mode'.")

(defvar bicep-ts-mode--indent-rules
  `((bicep
     ((node-is "}") parent-bol 0)
     ((node-is "]") parent-bol 0)
     ((parent-is "array") parent-bol bicep-ts-mode-indent-offset)
     ((parent-is "object") parent-bol bicep-ts-mode-indent-offset)
     ((parent-is "for_statement") parent-bol bicep-ts-mode-indent-offset))))

(defvar bicep-ts-mode--keywords
  '("var" "param" "resource" "func"
    "module" "type" "metadata"
    "targetScope" "output"
    "for" "in" "using")
  "Bicep keywords for tree-sitter font-locking.")

(defvar bicep-ts-mode--font-lock-settings
      (treesit-font-lock-rules
       :language 'bicep
       :feature 'comment
       '((comment) @font-lock-comment-face)

       :language 'bicep
       :feature 'delimiter
       '(("=") @font-lock-delimiter-face)

       :language 'bicep
       :feature 'keyword
       `([,@bicep-ts-mode--keywords] @font-lock-keyword-face)

       :language 'bicep
       :feature 'definition
       '((type) @font-lock-type-face
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
          (identifier) @font-lock-variable-name-face)
         (output_declaration
          (identifier) @font-lock-variable-name-face)
         )

       :language 'bicep
       :feature 'number
       '((number)
         @font-lock-number-face)

       :language 'bicep
       :feature 'string
       '((string_content) @font-lock-string-face)

       :language 'bicep
       :feature 'boolean
       '((boolean) @font-lock-constant-face)

       :language 'bicep
       :feature 'functions
       '((call_expression
          function: (identifier) @font-lock-function-name-face))

       :language 'bicep
       :feature 'error
       :override t
       '((ERROR) @font-lock-warning-face))
      "Font-lock settings for BICEP.")

(defun bicep-ts-mode--defun-name (node)
  "Return the defun name of NODE.
Return nil if there is no name or if NODE is not a defun node."
  (treesit-node-text
   (treesit-node-child node 1)
   t))

;;;###autoload
(define-derived-mode bicep-ts-mode prog-mode "Bicep"
  "Major mode for editing BICEP, powered by tree-sitter."
  :group 'bicep-mode

  (when (treesit-ready-p 'bicep)
    (treesit-parser-create 'bicep)

    ;; Comments
    (setq-local comment-start "# ")
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

;;;###autoload
(and (fboundp 'treesit-ready-p)
     (treesit-ready-p 'bicep)
     (progn
       (add-to-list 'auto-mode-alist '("\\.bicep\\(param\\)?\\'"
                                       . bicep-ts-mode))))

(provide 'bicep-ts-mode)

;;; bicep-ts-mode.el ends here
