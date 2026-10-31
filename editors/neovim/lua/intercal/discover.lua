-- Finding the CLI that is both the compiler and the language server: serverPath, else
-- ioi-<flavor>, else ciwapa-<flavor> (the ioi-* server understands everything ciwapa-* does).
local M = {}

local function kind_of(path)
	local name = vim.fs.basename(path)
	return name:match('^ciwapa%-') and 'ciwapa' or 'ioi'
end

-- Returns {path, kind = 'ioi'|'ciwapa'}, or nil and the names that were looked for.
-- `exepath` is vim.fn.exepath, replaceable in tests.
function M.find(options, exepath)
	exepath = exepath or vim.fn.exepath
	if options.serverPath and options.serverPath ~= '' then
		local wanted = vim.fn.expand(options.serverPath)
		local path = exepath(wanted)
		if path == '' then
			return nil, { wanted }
		end
		return { path = path, kind = kind_of(path) }
	end
	local looked_for = {}
	for _, kind in ipairs({ 'ioi', 'ciwapa' }) do
		local name = kind .. '-' .. options.flavor
		local path = exepath(name)
		if path ~= '' then
			return { path = path, kind = kind }
		end
		table.insert(looked_for, name)
	end
	return nil, looked_for
end

return M
