# bicep-ts-mode

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

