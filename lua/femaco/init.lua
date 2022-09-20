local M = {}

local update_config = function(opts)
  local config = require('femaco.config')
  opts = opts or {}
  for key, value in pairs(opts) do
    config.settings[key] = value
  end
end

local create_commands = function()
  vim.api.nvim_create_user_command('FeMaco', function() require('femaco.edit').edit_code_block() end, {})
end

M.setup = function(opts)
  update_config(opts)
  create_commands()
end

return M
