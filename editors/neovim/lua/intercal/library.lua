-- R6: the system library and EXTRACAL's library open as read-only buffers whose text comes from
-- the server (intercal/librarySource). Nothing is written to disk (Q165).
local lsp = require('intercal.lsp')

local M = {}

M.scheme = 'ciwapa-lib'
M.timeout_ms = 5000

local function fill(bufnr, lines)
	vim.bo[bufnr].modifiable = true
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.bo[bufnr].buftype = 'nofile'
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].modified = false
	vim.bo[bufnr].modifiable = false
	vim.bo[bufnr].readonly = true
end

-- A BufReadCmd for ciwapa-lib: buffers.
function M.read(bufnr, uri)
	local client = lsp.running_client()
	if not client then
		fill(bufnr, { 'PLEASE NOTE THAT THE LIBRARY LIVES IN THE LANGUAGE SERVER, AND IT IS NOT RUNNING' })
		return
	end
	local response, err = client:request_sync('intercal/librarySource', { uri = uri }, M.timeout_ms, bufnr)
	local failure = err or (response and response.err and response.err.message)
	if failure or not response or type(response.result) ~= 'table' then
		vim.notify(('INTERCAL: could not read %s: %s'):format(uri, tostring(failure or 'no answer')), vim.log.levels.ERROR, { title = 'INTERCAL' })
		fill(bufnr, {})
		return
	end
	local text = response.result.text:gsub('\r\n', '\n'):gsub('\n$', '')
	fill(bufnr, vim.split(text, '\n', { plain = true }))
	vim.bo[bufnr].filetype = 'intercal'
end

return M
