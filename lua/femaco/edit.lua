local ts = vim.treesitter
local get_node_range = ts.get_node_range
if ts.get_node_range == nil then
  get_node_range = require("nvim-treesitter.ts_utils").get_node_range
end
local query = require("nvim-treesitter.query")

local any = require("femaco.utils").any
local clip_val = require("femaco.utils").clip_val
local settings = require("femaco.config").settings

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
    return get_node_range(match.node)
  end
end

local get_match_text = function(match, bufnr)
  local srow, scol, erow, ecol = get_match_range(match)
  return table.concat(vim.api.nvim_buf_get_text(bufnr, srow, scol, erow, ecol, {}), "\n")
end

local parse_match = function(match)
  local language = match.language or match._lang or (match.injection and match.injection.language)
  if language == nil then
    for lang, val in pairs(match) do
      return {
        lang = lang,
        content = val,
      }
    end
  end
  local lang
  local lang_range
  if type(language) == "string" then
    lang = language
  else
    lang = get_match_text(language, 0)
    lang_range = { get_match_range(language) }
  end
  local content = match.content or (match.injection and match.injection.content)

  return {
    lang = lang,
    lang_range = lang_range,
    content = content,
  }
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

  local matches = query.get_matches(vim.api.nvim_get_current_buf(), "injections")
  local before_cursor = {}
  local after_cursor = {}
  for _, match in ipairs(matches) do
    local match_data = parse_match(match)
    local content_range = { get_match_range(match_data.content) }
    local ranges = { content_range }
    if match_data.lang_range then
      table.insert(ranges, match_data.lang_range)
    end
    if any(contains_cursor, ranges) then
      return { lang = match_data.lang, content = match_data.content, range = content_range }
    elseif any(is_after_cursor, ranges) then
      table.insert(after_cursor, { lang = match_data.lang, content = match_data.content, range = content_range })
    elseif any(is_before_cursor, ranges) then
      table.insert(before_cursor, { lang = match_data.lang, content = match_data.content, range = content_range })
    end
  end
  if #after_cursor > 0 then
    return after_cursor[1]
  elseif #before_cursor > 0 then
    return before_cursor[#before_cursor]
  end
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

local tbl_equal = function(left_tbl, right_tbl)
  local equal = true
  for k, v in pairs(right_tbl) do
    if left_tbl[k] ~= v then
      equal = false
      break
    end
  end
  return equal
end

-- Calculate the indent size based on the smallest indent
-- if a line with non-whitespace characters.
local get_ident_sizes = function(lines)
  local first_indent_size, last_indent_size, smallest_indent_size = nil, nil, nil
  for i, line in ipairs(lines) do
    local indent_size_line = #line:match("^%s*")
    local is_whitespace_only_line = line:match("^%s*$") ~= nil
    if is_whitespace_only_line and i == 1 then
      first_indent_size = indent_size_line
    elseif is_whitespace_only_line and i == #lines then
      last_indent_size = indent_size_line
    elseif not is_whitespace_only_line then
      if smallest_indent_size == nil or (indent_size_line < smallest_indent_size) then
        smallest_indent_size = indent_size_line
      end
    end
  end
  local indent_size = 0
  if smallest_indent_size ~= nil then
    indent_size = smallest_indent_size
  end
  return {
    first_indent_size = first_indent_size,
    last_indent_size = last_indent_size,
    indent_size = indent_size,
  }
end

-- Strips leading indent from lines, if present. First and last row is handled
-- as special cases; they are removed entirely if the provided indent_sizes are
-- a match for the respective line (rely on re_indent_lines to restore them).
local un_indent_lines = function(lines, indent_sizes)
  local indent_char = nil

  local lines_out, lines_out_len = {}, 0
  local function push_line(line)
    lines_out_len = lines_out_len + 1
    lines_out[lines_out_len] = line
  end

  for i, line in ipairs(lines) do
    local leading_whitespace = line:match("^%s*")
    local leading_whitespace_size = #leading_whitespace

    if i == 1 and leading_whitespace_size == indent_sizes.first_indent_size then
      -- strip line, rely on auto insert post-edit
    elseif i == #lines and leading_whitespace_size == indent_sizes.last_indent_size then
      -- strip line, rely on auto insert post-edit
    else
      if indent_char == nil then
        indent_char = leading_whitespace:sub(1, 1)
      end

      -- Check that all leading whitespace is the same. We have this strict requirement
      -- since we don't know which whitespace to insert after the edit if there's mixed
      -- ones to begin with.
      for j = 1, #leading_whitespace do
        if leading_whitespace:sub(j, j) ~= indent_char then
          return lines, nil
        end
      end
      if #leading_whitespace >= indent_sizes.indent_size then
        push_line(line:sub(indent_sizes.indent_size + 1))
      else
        push_line(line)
      end
    end
  end

  return lines_out, indent_char
end

-- Inserts leading indent to lines. First and last row is handled in a special
-- way; they are inserted with the provided first and last indent sizes,
-- respectively. It is assumed that they were previously stripped before the
-- content was edited, so we don't need to treat the edited first and last row
-- in any special way.
local re_indent_lines = function(lines, indent_sizes, indent_char)
  local lines_out, lines_out_len = {}, 0
  local function push_line(line)
    lines_out_len = lines_out_len + 1
    lines_out[lines_out_len] = line
  end

  local indent = string.rep(indent_char or " ", indent_sizes.indent_size)
  -- Restore original first whitespace only line
  if indent_sizes.first_indent_size then
    push_line(string.rep(indent_char or " ", indent_sizes.first_indent_size))
  end
  for _, line in ipairs(lines) do
    if #line == 0 then
      push_line(line) -- let empty lines remain empty
    else
      push_line(indent .. line)
    end
  end
  -- Restore original trailing whitespace only line
  if indent_sizes.last_indent_size then
    push_line(string.rep(indent_char or " ", indent_sizes.last_indent_size))
  end
  return lines_out
end

M.edit_code_block = function()
  local bufnr = vim.fn.bufnr()
  local base_filetype = vim.bo.filetype
  local match_data = get_match_at_cursor()
  if match_data == nil then
    return
  end
  local match_lines = vim.split(get_match_text(match_data.content, 0), "\n")
  local filetype = settings.ft_from_lang(match_data.lang)
  local indent_sizes, lines_for_edit, indent_char = nil, match_lines, nil
  local should_normalize_indent = settings.normalize_indent(base_filetype)
  if should_normalize_indent then
    indent_sizes = get_ident_sizes(match_lines)
    if indent_sizes.indent_size > 0 then
      lines_for_edit, indent_char = un_indent_lines(match_lines, indent_sizes)
    end
  end

  -- NOTE that we do this before opening the float
  local float_cursor = get_float_cursor(match_data.range, lines_for_edit)
  local range = match_data.range
  local winnr = settings.prepare_buffer(settings.float_opts({
    range = range,
    lines = lines_for_edit,
    lang = match_data.lang,
  }))

  vim.cmd("file " .. settings.create_tmp_filepath(filetype))
  vim.bo.filetype = filetype

  vim.api.nvim_buf_set_lines(vim.fn.bufnr(), 0, -1, true, lines_for_edit)
  -- use nvim_exec to do this silently
  vim.api.nvim_exec("write!", true)
  vim.api.nvim_win_set_cursor(0, float_cursor)
  settings.post_open_float(winnr)

  local float_bufnr = vim.fn.bufnr()
  vim.api.nvim_create_autocmd({ "BufWritePost", "WinClosed" }, {
    buffer = 0,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(float_bufnr, 0, -1, true)

      if tbl_equal(lines_for_edit, lines) then
        return -- unmodified
      end

      if lines[#lines] ~= "" and settings.ensure_newline(base_filetype) then
        table.insert(lines, "")
      end
      local sr, sc, er, ec = unpack(range)
      if should_normalize_indent and indent_char and indent_sizes and indent_sizes.indent_size > 0 then
        lines = re_indent_lines(lines, indent_sizes, indent_char)
      end
      vim.api.nvim_buf_set_text(bufnr, sr, sc, er, ec, lines)
      update_range(range, lines)
    end,
  })
  -- make sure the buffer is deleted when we close the window
  -- useful if user has hidden set
  vim.api.nvim_create_autocmd("BufHidden", {
    buffer = 0,
    callback = function()
      vim.schedule(function()
        if vim.api.nvim_buf_is_loaded(float_bufnr) then
          vim.cmd(string.format("bdelete! %d", float_bufnr))
        end
      end)
    end,
  })
end

return M
