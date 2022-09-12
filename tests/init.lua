vim.o.runtimepath = vim.o.runtimepath .. ',./rtps/plenary.nvim'
vim.o.runtimepath = vim.o.runtimepath .. ',./rtps/nvim-treesitter'
vim.o.runtimepath = vim.o.runtimepath .. ',.'

require('nvim-treesitter').setup()
