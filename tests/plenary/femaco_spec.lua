local set_query = vim.treesitter.query.set_query or vim.treesitter.set_query or vim.treesitter.query.set

local function escape_keys(keys)
  return vim.api.nvim_replace_termcodes(keys, true, false, true)
end

local function feedkeys(keys)
  vim.api.nvim_feedkeys(escape_keys(keys), 'xmt', true)
end

local set_buf_text = function(text)
  vim.api.nvim_buf_set_lines(0, 0, -1, true, vim.split(text, '\n'))
end

local get_buf_text = function(bufnr)
  return vim.fn.join(vim.api.nvim_buf_get_lines(bufnr or 0, 0, -1, true), '\n')
end

local set_option = function(name, value)
  vim.api.nvim_buf_set_option(0, name, value)
end

local get_option = function(name)
  return vim.api.nvim_buf_get_option(0, name)
end

local parse = function(ft)
  vim.treesitter.get_parser(0, ft):parse()
end

local set_ft = function(ft)
  set_option('filetype', ft)
  parse(ft)
end

local get_ft = function()
  return get_option('filetype')
end

local set_cursor = function(row, col)
  vim.api.nvim_win_set_cursor(0, {row, col})
end

local get_cursor = function()
  return vim.api.nvim_win_get_cursor(0)
end

describe("markdown code blocks", function()
  after_each(function()
    package.loaded['femaco'] = nil
    package.loaded['femaco.edit'] = nil
    package.loaded['femaco.config'] = nil
  end)

  it("open code block, before first line", function()
    set_buf_text([[

```python
print()
```
]])
    set_ft('markdown')
    require('femaco').setup()
    local bufnr = vim.fn.bufnr()
    vim.cmd('FeMaco')
    -- No float should have been opened
    assert.are.equal(bufnr, vim.fn.bufnr())
  end)

  it("open code block, first line", function()
    set_buf_text([[
```python
print()
```
]])
    set_ft('markdown')
    require('femaco').setup()
    vim.cmd('FeMaco')
    assert.are.equal(get_buf_text(), 'print()\n')
    assert.are.equal(get_ft(), 'python')
    assert.same(get_cursor(), {1, 0})
    vim.cmd('q')
  end)

  it("open code block, middle", function()
    set_buf_text([[
```python
print()
print()
print()
```
]])
    set_ft('markdown')
    require('femaco').setup()
    set_cursor(3, 3)
    vim.cmd('FeMaco')
    assert.are.equal(get_buf_text(), [[
print()
print()
print()
]])
    assert.are.equal(get_ft(), 'python')
    assert.same(get_cursor(), {2, 3})
    vim.cmd('q')
  end)

  it("open code block, last line", function()
    set_buf_text([[
```python
print()
```
]])
    set_ft('markdown')
    require('femaco').setup()
    set_cursor(3, 2)
    vim.cmd('FeMaco')
    assert.are.equal(get_buf_text(), 'print()\n')
    assert.are.equal(get_ft(), 'python')
    assert.same(get_cursor(), {2, 0})
    vim.cmd('q')
  end)

  it("open code block, after last line", function()
    set_buf_text([[
```python
print()
```

]])
    set_ft('markdown')
    require('femaco').setup()
    set_cursor(4, 0)
    local bufnr = vim.fn.bufnr()
    vim.cmd('FeMaco')
    -- No float should have been opened
    assert.are.equal(bufnr, vim.fn.bufnr())
  end)

  it("open code block, edit save edit exit", function()
    set_buf_text([[
```python
print()
```
]])
    set_ft('markdown')
    require('femaco').setup()
    set_cursor(1, 0)
    local bufnr = vim.fn.bufnr()
    vim.cmd('FeMaco')
    feedkeys('yypp')
    vim.cmd('w')
    assert.are.equal(get_buf_text(bufnr), [[
```python
print()
print()
print()
```
]])
    feedkeys('dd')
    vim.cmd('w')
    assert.are.equal(get_buf_text(bufnr), [[
```python
print()
print()
```
]])
    feedkeys('kyypp')
    vim.cmd('q')
    assert.are.equal(get_buf_text(bufnr), [[
```python
print()
print()
print()
print()
```
]])
  end)

  it("create_tmp_filepath", function()
    set_buf_text([[
```python
print()
```
]])
    set_ft('markdown')
    require('femaco').setup({create_tmp_filepath = function(filetype) return '/tmp/foobar_femaco_'..filetype end})
    vim.cmd('FeMaco')
    assert.are.equal(vim.fn.bufname(), '/tmp/foobar_femaco_python')
    vim.cmd('q')
  end)

  it("ensure_newline", function()
    set_buf_text([[
```python
print()
```
]])
    set_ft('markdown')
    require('femaco').setup({ensure_newline = function(base_filetype) return base_filetype == 'markdown' end})
    vim.cmd('FeMaco')
    feedkeys('Gdd')
    vim.cmd('wq')
    assert.are.equal(get_buf_text(), [[
```python
print()
```
]])
  end)
end)

describe("inline languge injections", function()
  before_each(function()
    local ts = vim.treesitter

    set_buf_text([[
print('local x = function() return 0 end', 'print()')
]])
    set_query('python', 'injections', '((string) @lua (#offset! @lua 0 1 0 -1))')
    set_ft('python')
    require('femaco').setup()
    set_cursor(1, 0)
  end)

  it("open injected lua", function()
    vim.cmd('FeMaco')
    assert.are.equal(get_buf_text(), 'local x = function() return 0 end')
    assert.are.equal(get_ft(), 'lua')
    assert.same(get_cursor(), {1, 0})
    vim.cmd('q')
  end)

  it("cursor position", function()
    set_cursor(1, 13)
    vim.cmd('FeMaco')
    assert.are.equal(get_buf_text(), 'local x = function() return 0 end')
    assert.are.equal(get_ft(), 'lua')
    assert.same(get_cursor(), {1, 6})
    vim.cmd('q')
  end)

  it("cursor between", function()
    set_cursor(1, 41)
    vim.cmd('FeMaco')
    assert.are.equal(get_buf_text(), 'print()')
    assert.are.equal(get_ft(), 'lua')
    assert.same(get_cursor(), {1, 0})
    vim.cmd('q')
  end)

  it("cursor last", function()
    set_cursor(1, 100)
    vim.cmd('FeMaco')
    assert.are.equal(get_buf_text(), 'print()')
    assert.are.equal(get_ft(), 'lua')
    assert.same(get_cursor(), {1, 6})
    vim.cmd('q')
  end)

  it("edit save edit quit", function()
    local bufnr = vim.fn.bufnr()
    vim.cmd('FeMaco')
    feedkeys('fxcltest<Esc>')
    vim.cmd('w')
    assert.are.equal(get_buf_text(bufnr), [[
print('local test = function() return 0 end', 'print()')
]])
    feedkeys('D')
    vim.cmd('w')
    assert.are.equal(get_buf_text(bufnr), [[
print('local tes', 'print()')
]])
    vim.cmd('q')
  end)
end)
