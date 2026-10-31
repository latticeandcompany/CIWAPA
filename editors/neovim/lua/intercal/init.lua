local M = {}

-- The compilers' version. The plugin only trusts a server of exactly this version (Q179).
M.version = '0.0.0'

M.defaults = {
	serverPath = '',
	flavor = 'llvm',
	traditional = false,
	clockface = false
}

M.options = vim.deepcopy(M.defaults)
M.did_setup = false

local warned = {}

function M.warn_once(key, message)
	if warned[key] then
		return
	end
	warned[key] = true
	vim.schedule(function()
		vim.notify(message, vim.log.levels.WARN, { title = 'INTERCAL' })
	end)
end

local function validate(options)
	vim.validate('serverPath', options.serverPath, 'string')
	vim.validate('flavor', options.flavor, function(flavor)
		return flavor == 'llvm' or flavor == 'dart'
	end, "'llvm' or 'dart'")
	vim.validate('traditional', options.traditional, 'boolean')
	vim.validate('clockface', options.clockface, 'boolean')
end

function M.setup(options)
	options = vim.tbl_extend('force', M.defaults, options or {})
	validate(options)
	M.options = options
	M.did_setup = true
	require('intercal.lsp').configure(options)
end

return M
