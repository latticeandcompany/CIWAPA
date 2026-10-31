-- R13: Run this file and Build this file, in a terminal, with the settings' compiler flags.
local intercal = require('intercal')
local discover = require('intercal.discover')

local M = {}

function M.command(subcommand, file)
	local cli, looked_for = discover.find(intercal.options)
	if not cli then
		return nil, looked_for
	end
	local command = { cli.path, subcommand, file }
	if intercal.options.traditional then
		table.insert(command, '--traditional')
	end
	if intercal.options.clockface then
		table.insert(command, '--clockface')
	end
	return command
end

-- subcommand is 'run' or 'build'.
function M.start(subcommand)
	local file = vim.api.nvim_buf_get_name(0)
	if file == '' or vim.bo.buftype ~= '' then
		vim.notify("INTERCAL: this buffer isn't a file, so there's nothing to " .. subcommand .. '.', vim.log.levels.WARN, { title = 'INTERCAL' })
		return
	end
	local command, looked_for = M.command(subcommand, file)
	if not command then
		vim.notify(('INTERCAL: found none of %s to %s this with. Install a CIWAPA release or set serverPath.')
			:format(table.concat(looked_for, ', '), subcommand), vim.log.levels.ERROR, { title = 'INTERCAL' })
		return
	end
	vim.cmd('silent update')
	vim.cmd('botright new')
	vim.fn.jobstart(command, { term = true, cwd = vim.fs.dirname(file) })
	vim.cmd('startinsert')
end

return M
