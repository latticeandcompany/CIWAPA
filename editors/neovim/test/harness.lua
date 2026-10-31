-- Shared by the plain-Lua checks, which run as `nvim --clean -l test/<name>.lua` (Q177).
local M = {}

M.root = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(vim.fn.fnamemodify(arg[0], ':p'))))
M.fixtures = M.root .. '/test/fixtures'
M.repo = vim.fs.dirname(vim.fs.dirname(M.root))
M.failures = 0

function M.add_to_runtimepath()
	if not vim.tbl_contains(vim.opt.runtimepath:get(), M.root) then
		vim.opt.runtimepath:prepend(M.root)
	end
end

function M.load_plugin()
	M.add_to_runtimepath()
	vim.cmd('filetype plugin on')
	vim.cmd('runtime plugin/intercal.lua')
end

function M.fail(message)
	io.stderr:write(('FAIL (nvim %s): %s\n'):format(tostring(vim.version()), message))
	os.exit(1)
end

function M.check(condition, message)
	if condition then
		return
	end
	M.failures = M.failures + 1
	io.stderr:write(('FAIL (nvim %s): %s\n'):format(tostring(vim.version()), message))
end

function M.equal(actual, expected, message)
	M.check(vim.deep_equal(actual, expected), ('%s: expected %s, got %s'):format(message, vim.inspect(expected), vim.inspect(actual)))
end

function M.finish(name)
	if M.failures > 0 then
		io.stderr:write(('%s: %d check(s) failed on nvim %s\n'):format(name, M.failures, tostring(vim.version())))
		os.exit(1)
	end
	io.stdout:write(('%s: ok on nvim %s\n'):format(name, tostring(vim.version())))
end

-- Collects vim.notify messages instead of showing them.
function M.capture_notifications()
	local messages = {}
	vim.notify = function(message, level)
		table.insert(messages, { message = message, level = level })
	end
	return messages
end

function M.drain()
	vim.wait(50, function()
		return false
	end)
end

return M
