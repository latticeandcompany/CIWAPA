-- R9: toggling comments is the server's job (intercal/toggleComment), because it works on whole
-- statements and knows that `PLEASE NOTE` is a comment only by accident of the lexer.
local lsp = require('intercal.lsp')

local M = {}

-- Toggles every statement on lines first..last (1-based, inclusive) of bufnr.
function M.toggle(bufnr, first, last)
	bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
	local client = lsp.client_for(bufnr)
	if not client then
		vim.notify('INTERCAL: no language server is attached, and toggling comments needs one.', vim.log.levels.WARN, { title = 'INTERCAL' })
		return
	end
	local last_line = vim.api.nvim_buf_get_lines(bufnr, last - 1, last, true)[1]
	local params = {
		textDocument = { uri = vim.uri_from_bufnr(bufnr) },
		range = {
			start = { line = first - 1, character = 0 },
			['end'] = { line = last - 1, character = vim.str_utfindex(last_line, client.offset_encoding) }
		}
	}
	client:request('intercal/toggleComment', params, function(err, edits)
		if err then
			vim.notify('INTERCAL: toggling the comment failed: ' .. err.message, vim.log.levels.ERROR, { title = 'INTERCAL' })
			return
		end
		if edits and #edits > 0 and vim.api.nvim_buf_is_valid(bufnr) then
			vim.lsp.util.apply_text_edits(edits, bufnr, client.offset_encoding)
		end
	end, bufnr)
end

-- An 'operatorfunc', and the expression that starts it (`gc`, `gcc`), like Neovim's own commenting.
function M.operator(motion)
	if motion == nil then
		vim.o.operatorfunc = "v:lua.require'intercal.comment'.operator"
		return 'g@'
	end
	local first = vim.api.nvim_buf_get_mark(0, '[')[1]
	local last = vim.api.nvim_buf_get_mark(0, ']')[1]
	M.toggle(0, first, last)
end

return M
