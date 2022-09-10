local ts = vim.treesitter
local query = require('nvim-treesitter.query')

local clip_val = require('femaco.utils').clip_val
local settings = require('femaco.config').settings

local M = {}

local get_code_block_at_cursor = function()
  local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
  local matches = query.get_matches(0, 'injections')
  for _, match in ipairs(matches) do
    local content = match.content.node
    local start_row, _, end_row, _ = ts.get_node_range(content)
    if start_row - 1 <= row - 1 and row - 1 <= end_row then
      return {
        start_row = start_row - 1,
        end_row = end_row + 1,
        lines = vim.split(ts.get_node_text(content, 0), '\n'),
        lang = ts.get_node_text(match.language.node, 0)
      }
    end
  end
end

local open_float = function(opts)
  local buf = vim.api.nvim_create_buf(false, false)
  return vim.api.nvim_open_win(buf, true, opts)
end

local get_ns_id = function()
  return vim.api.nvim_create_namespace('femaco')
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
  local winnr = open_float(settings.float_opts(code_block))

  vim.cmd('file ' .. os.tmpname())
  vim.bo.filetype = settings.ft_from_lang(code_block.lang)
  vim.api.nvim_buf_set_lines(vim.fn.bufnr(), 0, -1, true, code_block.lines)
  -- use nvim_exec to do this silently
  vim.api.nvim_exec('write!', true)
  vim.api.nvim_win_set_cursor(0, {
    clip_val(1, cursor_row - code_block.start_row - 1, vim.api.nvim_buf_line_count(0)),
    cursor_col,
  })
  settings.post_open_float(winnr)

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
        if vim.api.nvim_buf_is_loaded(float_bufnr) then
          vim.cmd(string.format('bdelete! %d', float_bufnr))
        end
      end)
    end,
  })
end

return M
