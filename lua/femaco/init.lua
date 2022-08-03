local M = {}

local update_config = function(opts)
  local config = require('femaco.config')
  opts = opts or {}
  config.settings = vim.tbl_extend('force', config.settings, opts)
end

local create_commands = function()
  vim.api.nvim_create_user_command('FeMaco', function() require('femaco.edit').edit_code_block() end, {})
end

M.setup = function(opts)
  update_config(opts)
  create_commands()
end

return M
