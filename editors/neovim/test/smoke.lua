-- The smoke test (R12, Q168, Q177): start the real server, open a sample with an error, see the
-- diagnostic, follow a go to definition from a NEXT to its label, then one into the system
-- library's read-only ciwapa-lib: buffer (R6).
-- Run: nvim --clean -l test/smoke.lua [server], the server defaulting to .cache/build/ciwapa-llvm.
local t = dofile(vim.fs.dirname(vim.fn.fnamemodify(arg[0], ':p')) .. '/harness.lua')

local timeout_ms = 15000
local server = arg[1] or (t.repo .. '/.cache/build/ciwapa-llvm')
if vim.fn.executable(server) == 0 then
	t.fail(('no server at %s. Build one first: tools/in-docker dart --suppress-analytics compile exe packages/ciwapa_llvm/bin/ciwapa_llvm.dart -o .cache/build/ciwapa-llvm'):format(server))
end

local notifications = t.capture_notifications()
t.add_to_runtimepath()
require('intercal').setup({ serverPath = server })
t.load_plugin()

local function step(name)
	io.stdout:write(('smoke: %s\n'):format(name))
end

local function wait_for(what, condition)
	if not vim.wait(timeout_ms, condition, 20) then
		t.fail(('timed out after %d ms waiting for %s'):format(timeout_ms, what))
	end
end

local function warnings()
	return vim.tbl_map(function(n)
		return n.message
	end, notifications)
end

step('open test/fixtures/sample.i')
vim.cmd.edit(t.fixtures .. '/sample.i')
if vim.bo.filetype ~= 'intercal' then
	t.fail(('sample.i has filetype %q, not intercal'):format(vim.bo.filetype))
end
local bufnr = vim.api.nvim_get_current_buf()

step('wait for the server to attach')
wait_for('the INTERCAL server to attach to sample.i', function()
	local client = require('intercal.lsp').client_for(bufnr)
	return client ~= nil and client.initialized
end)
local client = require('intercal.lsp').client_for(bufnr)
local server_info = client.server_info or {}
step(('attached to %s %s'):format(tostring(server_info.name), tostring(server_info.version)))
if #notifications > 0 then
	t.fail('the plugin warned while starting the server: ' .. table.concat(warnings(), ' | '))
end

step('wait for the diagnostic')
wait_for('a diagnostic on sample.i', function()
	return #vim.diagnostic.get(bufnr) > 0
end)
local diagnostics = vim.diagnostic.get(bufnr)
local e017 = vim.tbl_filter(function(d)
	return d.lnum == 5 and d.message:find('ICL017I', 1, true) ~= nil
end, diagnostics)
if #e017 ~= 1 then
	t.fail(('expected one ICL017I diagnostic on line 6, got %s'):format(vim.inspect(diagnostics)))
end
step(('line %d: %s'):format(e017[1].lnum + 1, e017[1].message:gsub('\n.*', '')))

step('go to definition from the NEXT on line 1')
if not client:supports_method('textDocument/definition', bufnr) then
	t.fail(('%s does not offer go to definition (no definitionProvider in its capabilities)'):format(server))
end
local use = vim.api.nvim_buf_get_lines(bufnr, 0, 1, true)[1]
vim.api.nvim_win_set_cursor(0, { 1, (assert(use:find('10', 1, true))) - 1 })
vim.lsp.buf.definition()
local label_line = 5
wait_for(('the cursor to land on the labelled statement, line %d'):format(label_line), function()
	return vim.api.nvim_win_get_cursor(0)[1] == label_line
end)
if vim.api.nvim_get_current_buf() ~= bufnr then
	t.fail(('go to definition left sample.i for %s'):format(vim.api.nvim_buf_get_name(0)))
end
step(('landed on line %d: %s'):format(label_line, vim.api.nvim_get_current_line()))

step('go to definition from the system library label on line 3 of library.i')
vim.cmd.edit(t.fixtures .. '/library.i')
local program = vim.api.nvim_get_current_buf()
wait_for('the INTERCAL server to attach to library.i', function()
	return require('intercal.lsp').client_for(program) ~= nil
end)
local call = vim.api.nvim_buf_get_lines(program, 2, 3, true)[1]
vim.api.nvim_win_set_cursor(0, { 3, (assert(call:find('1009', 1, true))) - 1 })
vim.lsp.buf.definition()
wait_for('a ciwapa-lib: buffer', function()
	return vim.api.nvim_buf_get_name(0):match('^ciwapa%-lib:') ~= nil
end)
local library = vim.api.nvim_get_current_buf()
local library_name = vim.api.nvim_buf_get_name(library)
local here = vim.api.nvim_get_current_line()
if not here:find('(1009)', 1, true) then
	t.fail(('%s opened at line %d, %q, not at (1009)'):format(library_name, vim.api.nvim_win_get_cursor(0)[1], here))
end
if not (vim.bo[library].readonly and not vim.bo[library].modifiable and vim.bo[library].buftype == 'nofile') then
	t.fail(library_name .. ' is not a read-only scratch buffer')
end
if #vim.lsp.get_clients({ bufnr = library }) > 0 then
	t.fail(library_name .. ' was sent to the server, which only takes file: documents')
end
step(('opened %s (%d lines) at line %d: %s'):format(library_name, vim.api.nvim_buf_line_count(library), vim.api.nvim_win_get_cursor(0)[1], here))

if #notifications > 0 then
	t.fail('the plugin warned: ' .. table.concat(warnings(), ' | '))
end
t.finish('smoke')
