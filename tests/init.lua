vim.o.runtimepath = vim.o.runtimepath .. ',./rtps/plenary.nvim'
vim.o.runtimepath = vim.o.runtimepath .. ',./rtps/nvim-treesitter'
vim.o.runtimepath = vim.o.runtimepath .. ',.'

_G.assert_equal_tables = function(tbl1, tbl2)
    assert(vim.deep_equal(tbl1, tbl2), string.format("%s ~= %s", vim.inspect(tbl1), vim.inspect(tbl2)))
end

require('nvim-treesitter').setup()
