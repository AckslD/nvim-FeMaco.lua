local M = {}

M.setup = function()
  vim.api.nvim_create_user_command('FeMaco', function() require('femaco.edit').edit_code_block() end, {})
end

return M
