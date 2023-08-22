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
These are the defaults:
```lua
require('femaco').setup({
  -- should prepare a new buffer and return the winid
  -- by default opens a floating window
  -- provide a different callback to change this behaviour
  -- @param opts: the return value from float_opts
  prepare_buffer = function(opts)
    local buf = vim.api.nvim_create_buf(false, false)
    return vim.api.nvim_open_win(buf, true, opts)
  end,
  -- should return options passed to nvim_open_win
  -- @param code_block: data about the code-block with the keys
  --   * range
  --   * lines
  --   * lang
  float_opts = function(code_block)
    return {
      relative = 'cursor',
      width = clip_val(5, 120, vim.api.nvim_win_get_width(0) - 10),  -- TODO how to offset sign column etc?
      height = clip_val(5, #code_block.lines, vim.api.nvim_win_get_height(0) - 6),
      anchor = 'NW',
      row = 0,
      col = 0,
      style = 'minimal',
      border = 'rounded',
      zindex = 1,
    }
  end,
  -- return filetype to use for a given lang
  -- lang can be nil
  ft_from_lang = function(lang)
    return lang
  end,
  -- what to do after opening the float
  post_open_float = function(winnr)
    vim.wo.signcolumn = 'no'
  end
  -- create the path to a temporary file, which will clear automatically
  create_tmp_filepath = function(filetype)
    return os.tmpname()
  end,
  -- if a newline should always be used, useful for multiline injections
  -- which separators needs to be on separate lines such as markdown, neorg etc
  -- @param base_filetype: The filetype which FeMaco is called from, not the
  -- filetype of the injected language (this is the current buffer so you can
  -- get it from vim.bo.filetyp).
  ensure_newline = function(base_filetype)
    return false
  end,
})
```

## Usage
Call `:FeMaco` or `require('femaco.edit').edit_code_block()` with your cursor on a code-block. Edit the content, then save and/or close the popup to update the original buffer.

## Credit
Thanks to everyone working on neovim core, lua-api, treesitter etc which have made plugins like these a joy to create!
