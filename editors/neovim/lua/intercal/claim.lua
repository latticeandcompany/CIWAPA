-- R11: which files are INTERCAL.
local M = {}

M.always = { '2i', '3i', '4i', '5i', '6i', '7i', '2xc', '3xc', '4xc', '5xc', '6xc', '7xc', 'ioi', '2ioi' }
M.ambiguous = { 'i', 'xc' }

M.lines_checked = 50

-- The session's answers to "Open it as INTERCAL anyway?", by absolute path. Never written to disk.
M.answers = {}
local asking = {}

local function starts_with_word(text, word)
	return text:sub(1, #word) == word and not text:sub(#word + 1, #word + 1):match('[%w_]')
end

-- `^\s*(\(\d+\)\s*)?(PLEASE|DO)\b`
function M.is_statement(line)
	local rest = line:match('^%s*(.*)$')
	rest = rest:match('^%(%d+%)%s*(.*)$') or rest
	return starts_with_word(rest, 'PLEASE') or starts_with_word(rest, 'DO')
end

function M.looks_like_intercal(lines)
	for i = 1, math.min(#lines, M.lines_checked) do
		if M.is_statement(lines[i]) then
			return true
		end
	end
	return false
end

local function builtin_filetype(extension, path, bufnr)
	if extension ~= 'i' then
		return nil
	end
	local ok, detect = pcall(require, 'vim.filetype.detect')
	if not ok or type(detect.i) ~= 'function' then
		return nil
	end
	local found_ok, filetype = pcall(detect.i, path, bufnr)
	return found_ok and filetype or nil
end

-- A headless Neovim has nobody to ask, and vim.ui.select would wait for stdin.
function M.can_ask()
	return #vim.api.nvim_list_uis() > 0
end

function M.ask(path, extension, bufnr)
	if asking[path] or M.answers[path] ~= nil or not M.can_ask() then
		return
	end
	asking[path] = true
	vim.ui.select({ 'Yes', 'No' }, {
		prompt = ("This .%s doesn't look like INTERCAL. Open it as INTERCAL anyway?"):format(extension)
	}, function(choice)
		asking[path] = nil
		M.answers[path] = choice == 'Yes'
		if M.answers[path] and vim.api.nvim_buf_is_valid(bufnr) then
			vim.bo[bufnr].filetype = 'intercal'
		end
	end)
end

-- A vim.filetype.add() extension function for .i and .xc.
function M.detect(path, bufnr)
	if not bufnr or bufnr < 0 or not vim.api.nvim_buf_is_valid(bufnr) or path:match('^%a[%w+.-]+:') then
		return nil
	end
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, M.lines_checked, false)
	if M.looks_like_intercal(lines) then
		return 'intercal'
	end
	local absolute = vim.fs.normalize(vim.fn.fnamemodify(path, ':p'))
	if M.answers[absolute] then
		return 'intercal'
	end
	local extension = path:match('%.(%w+)$')
	if M.answers[absolute] == nil then
		vim.schedule(function()
			M.ask(absolute, extension, bufnr)
		end)
	end
	return builtin_filetype(extension, path, bufnr)
end

function M.register()
	local extension = {}
	for _, ext in ipairs(M.always) do
		extension[ext] = 'intercal'
	end
	for _, ext in ipairs(M.ambiguous) do
		extension[ext] = M.detect
	end
	vim.filetype.add({ extension = extension })
end

return M
