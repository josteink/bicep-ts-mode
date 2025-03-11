# bicep-ts-mode

[![CI](https://github.com/josteink/bicep-ts-mode/actions/workflows/ci.yml/badge.svg)](https://github.com/josteink/bicep-ts-mode/actions/workflows/ci.yml)

[Bicep](https://github.com/Azure/bicep)-support for [GNU
Emacs](https://www.gnu.org/software/emacs/), powered by the
[tree-sitter](https://tree-sitter.github.io/tree-sitter/) parser library.

## Features supported

- Syntax highlighting
- Indentation
- Imenu-support, when LSP not configured
- Automatic eglot-configuration, if Bicep Langserver found with
  configurable default search-location (by default it looks for
  location installed by VSCode Bicep-extension)

## Prerequisites

To use this package with GNU Emacs you need the following
prerequisites:

- GNU Emacs built with tree-sitter support enabled
- [Bicep language grammar for tree-sitter](https://github.com/amaanq/tree-sitter-bicep)

## Installation

Right now neither the tree-sitter grammar, nor the major-mode is
published or distributed in any official or semi-official
package-manager, so you will have to install both manually.

1. Verify Emacs has tree-sitter support enabled. In `C-h v
   system-configuration-features` look for `TREE_SITTER`.
2. Install the tree-sitter grammar `M-x
   treesit-install-language-grammar`, and provide `bicep` as
   name and `https://github.com/amaanq/tree-sitter-bicep` as
   source repo. Use defaults for everything else.
3. Clone the repo somewhere locally and load it from there. The
   following use-package statement might also work:

```lisp
(use-package bicep-ts-mode
  :ensure t
  :vc ( :url "https://github.com/josteink/bicep-ts-mode"
        :rev :newest))
```

If you have any issues or corrections, feel free to provide a PR to
help others :)

