# FeMaco
:exclamation: Originally this was written for only markdown code blocks. However this plugin now support any language injection in any language!

Catalyze your **Fe**nced **Ma**rkdown **Co**de-block editing!

![FeMoco_cluster](https://user-images.githubusercontent.com/23341710/182566777-492c5e81-95fc-4443-ae6a-23ba2519960e.png)
(based on [this](https://en.wikipedia.org/wiki/FeMoco#/media/File:FeMoco_cluster.svg))

A small plugin allowing to edit injected language trees with correct filetype in a floating window.
This allows you to use all of your config for your favorite language.
The buffer will be also linked to a temporary file in order to allow LSPs to work properly.

Powered by treesitter, lua and coffee.

https://user-images.githubusercontent.com/23341710/182567238-e1f7bbcc-1f0c-43de-b17d-9d5576aba873.mp4

## Installation
For example using [`packer`](https://github.com/wbthomason/packer.nvim):
```lua
use {
  'AckslD/nvim-FeMaco.lua',
  config = 'require("femaco").setup()',
}
```
Requires [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter).

## Configuration
Pass a dictionary into `require("femaco").setup()` with callback functions.
See [`config`](https://github.com/AckslD/nvim-FeMaco.lua/blob/main/lua/femaco/config.lua) for available options.


## Usage
Call `:FeMaco` or `require('femaco.edit').edit_code_block()` with your cursor on a code-block. Edit the content, then save and/or close the popup to update the original buffer.

## Credit
Thanks to everyone working on neovim core, lua-api, treesitter etc which have made plugins like these a joy to create!
