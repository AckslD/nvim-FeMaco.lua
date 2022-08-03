# FeMaco
Catalyze your **Fe**nced **Ma**rkdown **Co**de-block editing!

A small plugin allowing to edit markdown code-blocks with correct filetype in a floating window.
This allows you to use all of your config for your favorite language.
The buffer will be also linked to a temporary file in order to allow LSPs to work properly.

Powered by treesitter, lua and coffee.

## Installation
For example using [`packer`](https://github.com/wbthomason/packer.nvim):
```lua
use {
  'AckslD/nvim-FeMaco.lua',
  config = 'require("femaco").setup()',
}
```
Requires [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter) with [markdown support](https://github.com/MDeiml/tree-sitter-markdown). Language injection not needed.

## Configuration
Pass a dictionary into `require("femaco").setup()` with callback functions.
See [`config`](https://github.com/AckslD/nvim-FeMaco.lua/blob/main/lua/femaco/config.lua) for available options.


## Usage
Call `:FeMaco` or `require('femaco.edit').edit_code_block()` with your cursor on a code-block. Edit the content, then save and/or close the popup to update the markdown buffer.

## Credit
Thanks to everyone working on neovim core, lua-api, treesitter etc which have made plugins like these a joy to create!
