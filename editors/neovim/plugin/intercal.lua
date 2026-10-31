if vim.g.loaded_intercal then
	return
end
vim.g.loaded_intercal = true

if vim.fn.has('nvim-0.11') == 0 then
	vim.notify('INTERCAL needs Neovim 0.11 or later.', vim.log.levels.ERROR, { title = 'INTERCAL' })
	return
end

require('intercal.claim').register()

local group = vim.api.nvim_create_augroup('intercal', { clear = true })

vim.api.nvim_create_autocmd('FileType', {
	group = group,
	pattern = 'intercal',
	callback = function(args)
		require('intercal.lsp').on_filetype(args.buf)
	end
})

vim.api.nvim_create_autocmd('BufReadCmd', {
	group = group,
	pattern = 'ciwapa-lib:/*',
	callback = function(args)
		require('intercal.library').read(args.buf, args.match)
	end
})

vim.api.nvim_create_user_command('IntercalRun', function()
	require('intercal.run').start('run')
end, { desc = 'Run this INTERCAL file in a terminal' })

vim.api.nvim_create_user_command('IntercalBuild', function()
	require('intercal.run').start('build')
end, { desc = 'Build this INTERCAL file in a terminal' })

vim.api.nvim_create_user_command('IntercalToggleComment', function(args)
	require('intercal.comment').toggle(0, args.line1, args.line2)
end, { range = true, desc = 'Toggle PLEASE NOTE on the statements in range' })

if not require('intercal').did_setup then
	require('intercal').setup()
end
