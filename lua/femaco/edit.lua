local ts = vim.treesitter
local query = require('nvim-treesitter.query')

local any = require('femaco.utils').any
local clip_val = require('femaco.utils').clip_val
local settings = require('femaco.config').settings

local M = {}

-- Maybe we could use https://github.com/nvim-treesitter/nvim-treesitter/pull/3487
-- if they get merged
local is_in_range = function(range, line, col)
  local start_line, start_col, end_line, end_col = unpack(range)
  if line >= start_line and line <= end_line then
    if line == start_line and line == end_line then
      return col >= start_col and col < end_col
    elseif line == start_line then
      return col >= start_col
    elseif line == end_line then
      return col < end_col
    else
      return true
    end
  else
    return false
  end
end

local get_match_range = function(match)
  if match.metadata ~= nil and match.metadata.range ~= nil then
    return unpack(match.metadata.range)
  else
    return ts.get_node_range(match.node)
  end
end

local get_match_text = function(match, bufnr)
  local srow, scol, erow, ecol = get_match_range(match)
  return table.concat(vim.api.nvim_buf_get_text(bufnr, srow, scol, erow, ecol, {}), '\n')
end

local parse_match = function(match)
    if match.language == nil then
      for lang, val in pairs(match) do
        return {
          lang = lang,
          content_match = val,
        }
      end
    else
      return {
        lang = get_match_text(match.language, 0),
        lang_match = match.language,
        content_match = match.content,
      }
    end
end

local get_match_at_cursor = function()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))

  local contains_cursor = function(range)
    return is_in_range(range, row - 1, col) or (range[3] == row - 1 and range[4] == col)
  end

  local is_after_cursor = function(range)
    return range[1] == row - 1 and range[2] > col
  end

  local is_before_cursor = function(range)
    return range[3] == row - 1 and range[4] < col
  end

  local matches = query.get_matches(0, 'injections')
  local before_cursor = {}
  local after_cursor = {}
  for _, match in ipairs(matches) do
    local match_data = parse_match(match)
    local content_range = {get_match_range(match_data.content_match)}
    local ranges = {content_range}
    if match_data.lang_match ~= nil then
      table.insert(ranges, {get_match_range(match_data.lang_match)})
    end
    if any(contains_cursor, ranges) then
      return {lang = match_data.lang, content = match_data.content_match, range = content_range}
    elseif any(is_after_cursor, ranges) then
      table.insert(after_cursor, {lang = match_data.lang, content = match_data.content_match, range = content_range})
    elseif any(is_before_cursor, ranges) then
      table.insert(before_cursor, {lang = match_data.lang, content = match_data.content_match, range = content_range})
    end
  end
  if #after_cursor > 0 then
    return after_cursor[1]
  elseif #before_cursor > 0 then
    return before_cursor[#before_cursor]
  end
end

local open_float = function(opts)
  local buf = vim.api.nvim_create_buf(false, false)
  return vim.api.nvim_open_win(buf, true, opts)
end

local get_float_cursor = function(range, lines)
  local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))

  local num_lines = #lines
  local float_cursor_row = cursor_row - range[1] - 1
  local float_cursor_col
  if float_cursor_row < 0 then
    float_cursor_row = 0
    float_cursor_col = 0
  elseif float_cursor_row >= num_lines then
    float_cursor_row = num_lines - 1
    float_cursor_col = 0
  elseif float_cursor_row == 0 then
    float_cursor_col = cursor_col - range[2]
  else
    float_cursor_col = cursor_col
  end

  return {
    float_cursor_row + 1,
    clip_val(0, float_cursor_col, #lines[float_cursor_row + 1]),
  }
end

local update_range = function(range, lines)
  if #lines == 0 then
    range[3] = range[1]
    range[4] = range[2]
  else
    range[3] = range[1] + #lines - 1
    if #lines == 1 then
      range[4] = range[2] + #lines[#lines]
    else
      range[4] = #lines[#lines]
    end
  end
end

M.edit_code_block = function()
  local bufnr = vim.fn.bufnr()
  local match_data = get_match_at_cursor()
  if match_data == nil then
    return
  end
  local match_lines = vim.split(get_match_text(match_data.content, 0), '\n')
  -- NOTE that we do this before opening the float
  local float_cursor = get_float_cursor(match_data.range, match_lines)
  local range = match_data.range
  local winnr = open_float(settings.float_opts({lines = match_lines, lang = match_data.lang}))

  vim.cmd('file ' .. os.tmpname())
  vim.bo.filetype = settings.ft_from_lang(match_data.lang)
  vim.api.nvim_buf_set_lines(vim.fn.bufnr(), 0, -1, true, match_lines)
  -- use nvim_exec to do this silently
  vim.api.nvim_exec('write!', true)
  vim.api.nvim_win_set_cursor(0, float_cursor)
  settings.post_open_float(winnr)

  local float_bufnr = vim.fn.bufnr()
  vim.api.nvim_create_autocmd({'BufWritePost', 'WinClosed'}, {
    buffer = 0,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, true)
      if #lines == 1 and lines[1] == '' then
        -- keep empty blocks empty, note that this does not allow the user to set an empty single line,
        -- but why would you want to do that anyway?
        lines = {}
      end
      -- TODO extract function
      local sr, sc, er, ec = unpack(range)
      vim.api.nvim_buf_set_text(bufnr, sr, sc, er, ec, lines)
      update_range(range, lines)
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
