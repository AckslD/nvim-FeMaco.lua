local ts = vim.treesitter
local ts_utils = require('nvim-treesitter.ts_utils')
local parsers = require('nvim-treesitter.parsers')

local clip_val = require('femaco.utils').clip_val
local settings = require('femaco.config').settings

local M = {}

local is_code_block = function(node)
  return node:type() == 'fenced_code_block'
end

local get_code_block_node_at_cursor = function()
  parsers.get_parser(0):parse()
  local node = ts_utils.get_node_at_cursor(0, true)
  while not is_code_block(node) do
    node = node:parent()
    if node == nil then
      return nil
    end
  end
  return node
end

local get_lang = function(fenced_code_block)
  local info_string = fenced_code_block:named_child(1)
  if info_string:type() ~= 'info_string' then
    return nil
  end
  local lang = info_string:named_child(0)
  if lang:type() ~= 'language' then
    return nil
  end
  return ts.get_node_text(lang, 0)
end

local get_content = function(fenced_code_block)
  local content = fenced_code_block:named_child(3)
  if content == nil then
    return ''
  end
  if content:type() ~= 'code_fence_content' then
    return ''
  end
  return ts.get_node_text(content, 0)
end

local get_code_block_at_cursor = function()
  local fenced_code_block = get_code_block_node_at_cursor()
  if fenced_code_block == nil then
    return nil
  end

  local start_row, _, end_row, _ = ts_utils.get_node_range(fenced_code_block)
  return {
    start_row = start_row,
    end_row = end_row,
    lines = vim.split(get_content(fenced_code_block), '\n'),
    lang = get_lang(fenced_code_block),
  }
end

local open_float = function(opts)
  local buf  = vim.api.nvim_create_buf(false, false)
  return vim.api.nvim_open_win(buf, 0, opts)
end

local get_ns_id = function()
  return vim.api.nvim_create_namespace('axel_markdown')
end

local clear_extmarks = function()
  local ns_id = get_ns_id()
  local extmarks = vim.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, {})
  for _, extmark in ipairs(extmarks) do
    vim.api.nvim_buf_del_extmark(0, ns_id, extmark[1])
  end
end

local make_extmarks = function(start_row, end_row)
  local ns_id = get_ns_id()
  clear_extmarks()
  return {
    start = vim.api.nvim_buf_set_extmark(0, ns_id, start_row, 0, {}),
    end_ = vim.api.nvim_buf_set_extmark(0, ns_id, end_row, 0, {}),
  }
end

local set_extmarks_lines = function(bufnr, lines, extmarks)
  local ns_id = get_ns_id()
  local start_row = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns_id, extmarks.start, {})[1]
  local end_row = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns_id, extmarks.end_, {})[1]
  vim.api.nvim_buf_set_lines(bufnr, start_row + 1, end_row - 1, true, lines)
end

local tbl_equal = function(t1, t2)
  if #t1 ~= #t2 then
    return false
  end
  for i, v in ipairs(t1) do
    if v ~= t2[i] then
      return false
    end
  end
  return true
end

M.edit_code_block = function()
  local bufnr = vim.fn.bufnr()
  local code_block = get_code_block_at_cursor()
  if code_block == nil then
    return
  end
  local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
  local extmarks = make_extmarks(code_block.start_row, code_block.end_row)
  open_float(settings.float_opts(code_block))

  vim.cmd('file ' .. os.tmpname())
  vim.bo.filetype = settings.ft_from_lang(code_block.lang)
  vim.api.nvim_buf_set_lines(vim.fn.bufnr(), 0, -1, true, code_block.lines)
  -- use nvim_exec to do this silently
  vim.api.nvim_exec('write!', true)
  vim.api.nvim_win_set_cursor(0, {
    clip_val(1, cursor_row - code_block.start_row - 1, vim.api.nvim_buf_line_count(0)),
    cursor_col,
  })
  settings.post_open_float()

  local float_bufnr = vim.fn.bufnr()
  vim.api.nvim_create_autocmd({'BufWritePost', 'WinClosed'}, {
    buffer = 0,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, true)
      if tbl_equal(lines, code_block.lines) then
        return
      end
      if #lines == 1 and lines[1] == '' then
        -- keep empty blocks empty, note that this does not allow the user to set an empty single line,
        -- but why would you want to do that anyway?
        lines = {}
      end
      set_extmarks_lines(bufnr, lines, extmarks)
    end,
  })
  -- make sure the buffer is deleted when we close the window
  -- useful if user has hidden set
  vim.api.nvim_create_autocmd('BufHidden', {
    buffer = 0,
    callback = function()
      vim.schedule(function()
        vim.cmd(string.format('bdelete! %d', float_bufnr))
      end)
    end,
  })
end

return M
