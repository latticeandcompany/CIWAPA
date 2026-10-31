local intercal = require('intercal')
local discover = require('intercal.discover')

local M = {}

M.name = 'intercal'
M.namespace = vim.api.nvim_create_namespace('intercal')

-- What discover.find() returned at the last setup(): {path, kind}, or nil.
M.server = nil
M.looked_for = {}

local setup_hint = "require('intercal').setup({ serverPath = '/path/to/ioi-llvm' })"

local function settings_of(options)
	return { intercal = { traditional = options.traditional, clockface = options.clockface } }
end

local function is_ioi(bufnr)
	return vim.api.nvim_buf_get_name(bufnr):match('%.2?ioi$') ~= nil
end

local function is_file(bufnr)
	local name = vim.api.nvim_buf_get_name(bufnr)
	return name ~= '' and not name:match('^%a[%w+.-]+:')
end

local function running_client()
	return vim.lsp.get_clients({ name = M.name })[1]
end

local function root_dir(bufnr, on_dir)
	if not is_file(bufnr) then
		return
	end
	local kind = M.server and M.server.kind
	if vim.bo[bufnr].filetype == 'html' then
		local client = running_client()
		if kind ~= 'ciwapa' and client then
			on_dir(client.root_dir)
		end
		return
	end
	if kind == 'ciwapa' and is_ioi(bufnr) then
		return
	end
	on_dir(vim.fs.root(bufnr, { '.git' }) or vim.fn.getcwd())
end

local function warn_missing()
	local message
	if intercal.options.serverPath ~= '' then
		message = ("INTERCAL: serverPath is '%s', and there's no program there. Fix it in %s, or leave it empty to search your PATH.")
			:format(intercal.options.serverPath, setup_hint)
	else
		message = ('INTERCAL: no language server. Looked on your PATH for %s and found nothing, which is the most reasonable thing INTERCAL will do for you today. Install a CIWAPA release, or point serverPath at one: %s')
			:format(table.concat(M.looked_for, ' and '), setup_hint)
	end
	intercal.warn_once('missing', message)
end

local function check_version(client, result)
	local version = vim.tbl_get(result or {}, 'serverInfo', 'version')
	if version == intercal.version then
		return
	end
	intercal.warn_once('version', ('INTERCAL: the language server %s is version %s, and this plugin is %s. They are released together and only agree with their own kind. Install the matching release, or point serverPath at one: %s')
		:format(client.config.cmd[1], tostring(version), intercal.version, setup_hint))
end

local function on_exit(code, signal, _)
	if code == 0 and signal == 0 then
		return
	end
	intercal.warn_once('crashed', ('INTERCAL: the language server %s fell over (exit code %d, signal %d). Reopen the file to start it again. If it keeps falling over, check serverPath: %s')
		:format(M.server and M.server.path or '', code, signal, setup_hint))
end

local function enable_code_lens(client, bufnr)
	if not client:supports_method('textDocument/codeLens', bufnr) then
		return
	end
	if vim.lsp.codelens.enable then
		vim.lsp.codelens.enable(true, { bufnr = bufnr })
		return
	end
	-- Neovim 0.11 has no codelens.enable(), so lenses are refreshed by hand.
	local group = vim.api.nvim_create_augroup('intercal-codelens-' .. bufnr, { clear = true })
	vim.api.nvim_create_autocmd({ 'BufEnter', 'CursorHold', 'InsertLeave' }, {
		group = group,
		buffer = bufnr,
		callback = function()
			vim.lsp.codelens.refresh({ bufnr = bufnr })
		end
	})
	vim.lsp.codelens.refresh({ bufnr = bufnr })
end

local function attach_open_templates(client)
	if M.server and M.server.kind == 'ciwapa' then
		return
	end
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].filetype == 'html' and is_file(bufnr) then
			vim.lsp.buf_attach_client(bufnr, client.id)
		end
	end
end

local function on_attach(client, bufnr)
	if vim.bo[bufnr].filetype ~= 'intercal' then
		return
	end
	if client:supports_method('textDocument/inlayHint', bufnr) then
		vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
	end
	enable_code_lens(client, bufnr)
	attach_open_templates(client)
end

function M.config(options)
	return {
		cmd = M.server and { M.server.path, 'lsp' } or nil,
		filetypes = { 'intercal', 'html' },
		root_dir = root_dir,
		init_options = {
			traditional = options.traditional,
			clockface = options.clockface,
			politenessInStatusBar = false
		},
		settings = settings_of(options),
		handlers = {
			-- The politeness ratio arrives as an inlay hint as well, so the notification is unused.
			['intercal/politeness'] = function() end
		},
		on_init = check_version,
		on_exit = on_exit,
		on_attach = on_attach
	}
end

function M.configure(options)
	M.server, M.looked_for = discover.find(options)
	vim.lsp.config(M.name, M.config(options))
	vim.lsp.enable(M.name, M.server ~= nil)
	for _, client in ipairs(vim.lsp.get_clients({ name = M.name })) do
		client.settings = settings_of(options)
		client:notify('workspace/didChangeConfiguration', { settings = client.settings })
	end
end

local function only_ciwapa_diagnostic(bufnr)
	local flavor = intercal.options.flavor
	vim.diagnostic.set(M.namespace, bufnr, {
		{
			lnum = 0,
			col = 0,
			severity = vim.diagnostic.severity.WARN,
			source = 'intercal',
			message = ('Only ciwapa-%s is installed, and it has never heard of INTERCAL on Interstates. Install ioi-%s (the ioi-%s release archive) to have this file checked.')
				:format(flavor, flavor, flavor)
		}
	})
end

-- For every buffer that becomes INTERCAL, whether or not a server will attach.
function M.on_filetype(bufnr)
	if not M.server then
		warn_missing()
		return
	end
	if M.server.kind == 'ciwapa' and is_ioi(bufnr) then
		only_ciwapa_diagnostic(bufnr)
	end
end

function M.client_for(bufnr)
	return vim.lsp.get_clients({ bufnr = bufnr, name = M.name })[1]
end

M.running_client = running_client

return M
