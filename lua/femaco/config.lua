local clip_val = require('femaco.utils').clip_val

local M = {}

M.settings = {
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
}

return M
