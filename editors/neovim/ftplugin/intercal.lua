if vim.b.did_ftplugin then
	return
end
vim.b.did_ftplugin = true

vim.bo.commentstring = 'PLEASE NOTE %s'
vim.b.undo_ftplugin = 'setlocal commentstring<'

if vim.g.no_plugin_maps or vim.g.no_intercal_maps then
	return
end

local comment = require('intercal.comment')
local opts = { buffer = true, expr = true }
vim.keymap.set({ 'n', 'x' }, 'gc', comment.operator, vim.tbl_extend('force', opts, { desc = 'Toggle INTERCAL comment' }))
vim.keymap.set('n', 'gcc', function()
	return comment.operator() .. '_'
end, vim.tbl_extend('force', opts, { desc = 'Toggle INTERCAL comment line' }))
vim.b.undo_ftplugin = vim.b.undo_ftplugin .. ' | silent! nunmap <buffer> gc | silent! xunmap <buffer> gc | silent! nunmap <buffer> gcc'
