-- Unit checks: the claiming regex and prompt (R11), discovery order (R13), library buffers (R6),
-- the comment mappings (R9) and the settings. Run: nvim --clean -l test/unit.lua
local t = dofile(vim.fs.dirname(vim.fn.fnamemodify(arg[0], ':p')) .. '/harness.lua')

local notifications = t.capture_notifications()
local empty_path = vim.fn.tempname()
vim.fn.mkdir(empty_path, 'p')
vim.env.PATH = empty_path
t.load_plugin()

local claim = require('intercal.claim')
local discover = require('intercal.discover')
local lsp = require('intercal.lsp')

-- Lockstep with the compilers (Q179): the plugin's version is ciwapa_core's.
local version_dart = table.concat(vim.fn.readfile(t.repo .. '/packages/ciwapa_core/lib/src/version.dart'), '\n')
t.equal(require('intercal').version, version_dart:match("ciwapaVersion = '([^']+)'"), "the plugin's version")

-- The R11 regex, `^\s*(\(\d+\)\s*)?(PLEASE|DO)\b`.
for _, line in ipairs({ 'DO GIVE UP', 'PLEASE GIVE UP', '\tPLEASE DO .1 <- #1', '(10) DO .1 <- #1', '(10)DO', '  (1)\tPLEASE NOTE', 'DO', 'DO,1 <- #2', 'PLEASE' }) do
	t.check(claim.is_statement(line), ('is a statement: %q'):format(line))
end
for _, line in ipairs({ '', 'do give up', 'DONT', 'PLEASEDO', 'DO_IT', '%module example', '(x) DO', '() DO', '(10) X DO', 'X DO', '#include "DO"' }) do
	t.check(not claim.is_statement(line), ('is not a statement: %q'):format(line))
end

local filler = {}
for i = 1, 49 do
	filler[i] = 'int x' .. i .. ';'
end
t.check(claim.looks_like_intercal(vim.list_extend(vim.deepcopy(filler), { 'DO GIVE UP' })), 'a statement on line 50 claims the file')
t.check(not claim.looks_like_intercal(vim.list_extend(vim.deepcopy(filler), { 'int x50;', 'DO GIVE UP' })), 'a statement on line 51 does not')

-- The unambiguous extensions, by name alone.
for _, ext in ipairs({ '2i', '3i', '4i', '5i', '6i', '7i', '2xc', '3xc', '4xc', '5xc', '6xc', '7xc', 'ioi', '2ioi' }) do
	t.equal(vim.filetype.match({ filename = 'prog.' .. ext }), 'intercal', '.' .. ext)
end
for _, ext in ipairs({ '3ioi', '7ioi', '8i', 'c' }) do
	t.check(vim.filetype.match({ filename = 'prog.' .. ext }) ~= 'intercal', '.' .. ext .. ' is not INTERCAL')
end

-- .i and .xc: claimed by content, otherwise asked about once per file.
local prompts = {}
local answer = 'Yes'
t.check(not claim.can_ask(), 'a headless Neovim is never asked')
claim.can_ask = function()
	return true
end
vim.ui.select = function(items, opts, on_choice)
	table.insert(prompts, opts.prompt)
	on_choice(answer)
end

vim.cmd.edit(t.fixtures .. '/sample.i')
t.equal(vim.bo.filetype, 'intercal', 'a .i with a statement')
t.equal(#prompts, 0, 'prompts for a .i with a statement')

local scratch = vim.fn.tempname()
vim.fn.mkdir(scratch, 'p')
local function copy(fixture, name)
	local path = scratch .. '/' .. name
	vim.fn.writefile(vim.fn.readfile(t.fixtures .. '/' .. fixture), path)
	return path
end

answer = 'No'
local swig = copy('swig.i', 'swig.i')
vim.cmd.edit(swig)
t.drain()
t.equal(prompts, { "This .i doesn't look like INTERCAL. Open it as INTERCAL anyway?" }, 'prompt for SWIG')
t.equal(vim.bo.filetype, 'swig', 'a declined .i keeps the built-in filetype')
vim.cmd('bwipeout')
vim.cmd.edit(swig)
t.drain()
t.equal(#prompts, 1, 'the answer for a file is remembered')
t.equal(vim.bo.filetype, 'swig', 'and still declined')

answer = 'Yes'
local xmos = copy('swig.i', 'chip.xc')
vim.cmd.edit(xmos)
t.drain()
t.equal(prompts[2], "This .xc doesn't look like INTERCAL. Open it as INTERCAL anyway?", 'prompt names the extension')
t.equal(vim.bo.filetype, 'intercal', 'an accepted .xc becomes INTERCAL')
vim.cmd('bwipeout')
vim.cmd.edit(xmos)
t.drain()
t.equal(#prompts, 2, 'an accepted answer is remembered')
t.equal(vim.bo.filetype, 'intercal', 'and reapplied')

-- No server anywhere: one warning, however many INTERCAL buffers open.
vim.cmd.edit(copy('sample.i', 'again.2i'))
t.drain()
local missing = vim.tbl_filter(function(n)
	return n.message:find('no language server', 1, true)
end, notifications)
t.equal(#missing, 1, 'missing-server warnings')
t.check(missing[1] and missing[1].message:find('serverPath', 1, true), 'the warning points at serverPath')

-- Discovery order: serverPath, then ioi-<flavor>, then ciwapa-<flavor>.
local function on_path(names)
	return function(name)
		return vim.tbl_contains(names, name) and '/bin/' .. name or ''
	end
end
local llvm = { serverPath = '', flavor = 'llvm' }
t.equal(discover.find(llvm, on_path({ 'ioi-llvm', 'ciwapa-llvm' })), { path = '/bin/ioi-llvm', kind = 'ioi' }, 'ioi-* first')
t.equal(discover.find(llvm, on_path({ 'ciwapa-llvm', 'ioi-dart' })), { path = '/bin/ciwapa-llvm', kind = 'ciwapa' }, 'then ciwapa-*, of the same flavor')
t.equal(discover.find({ serverPath = '', flavor = 'dart' }, on_path({ 'ioi-llvm', 'ciwapa-dart' })), { path = '/bin/ciwapa-dart', kind = 'ciwapa' }, 'flavor picks the CLI')
local server, looked_for = discover.find(llvm, on_path({}))
t.equal({ server, looked_for }, { nil, { 'ioi-llvm', 'ciwapa-llvm' } }, 'nothing found')
t.equal(discover.find({ serverPath = 'ciwapa-dart', flavor = 'llvm' }, on_path({ 'ioi-llvm', 'ciwapa-dart' })), { path = '/bin/ciwapa-dart', kind = 'ciwapa' }, 'serverPath wins')
t.equal(discover.find({ serverPath = 'my-server', flavor = 'llvm' }, on_path({ 'my-server' })), { path = '/bin/my-server', kind = 'ioi' }, 'an unrecognised serverPath is trusted with everything')
server, looked_for = discover.find({ serverPath = '/nowhere/ioi-llvm', flavor = 'llvm' }, on_path({ 'ioi-llvm' }))
t.equal({ server, looked_for }, { nil, { '/nowhere/ioi-llvm' } }, 'a wrong serverPath is not second-guessed')

local function fresh()
	for _, client in ipairs(vim.lsp.get_clients()) do
		client:stop()
	end
	vim.wait(5000, function()
		return #vim.lsp.get_clients() == 0
	end, 20)
	vim.cmd('silent %bwipeout!')
end

-- The real PATH, with stand-in CLIs that are never started.
fresh()
local bin = vim.fn.tempname()
vim.fn.mkdir(bin, 'p')
local function stand_in(name)
	vim.fn.writefile({ '#!/bin/sh', 'exit 3' }, bin .. '/' .. name)
	vim.uv.fs_chmod(bin .. '/' .. name, 493)
end
stand_in('ciwapa-dart')
vim.env.PATH = bin
require('intercal').setup({ flavor = 'dart', traditional = true })
t.equal(lsp.server, { path = bin .. '/ciwapa-dart', kind = 'ciwapa' }, 'setup discovers the server')
t.equal(require('intercal.run').command('build', '/w/prog.i'), { bin .. '/ciwapa-dart', 'build', '/w/prog.i' }, 'Build uses the discovered CLI')
local config = lsp.config(require('intercal').options)
t.equal(config.cmd, { bin .. '/ciwapa-dart', 'lsp' }, 'server command')
t.equal(config.init_options, { traditional = true, clockface = false, politenessInStatusBar = false }, 'initializationOptions')
t.equal(config.settings, { intercal = { traditional = true, clockface = false } }, 'settings')
t.equal(config.filetypes, { 'intercal', 'html' }, 'filetypes')

-- With only ciwapa-*, a .ioi file gets the plugin's own diagnostic and no server.
vim.cmd.edit(copy('sample.i', 'blog.ioi'))
local ioi_diagnostics = vim.diagnostic.get(0, { namespace = lsp.namespace })
t.equal(#ioi_diagnostics, 1, '.ioi diagnostics with only ciwapa-*')
t.check(ioi_diagnostics[1] and ioi_diagnostics[1].message:find('ioi-dart', 1, true), 'the diagnostic says to install ioi-dart')
t.drain()
t.equal(#vim.lsp.get_clients({ bufnr = 0 }), 0, 'ciwapa-* is not started for a .ioi file')

stand_in('ioi-dart')
fresh()
require('intercal').setup({ flavor = 'dart' })
t.equal(require('intercal.run').command('run', '/w/prog.i'), { bin .. '/ioi-dart', 'run', '/w/prog.i' }, 'Run prefers ioi-*')
t.check(not pcall(require('intercal').setup, { flavor = 'rust' }), 'flavor must be llvm or dart')
t.check(not pcall(require('intercal').setup, { traditional = 'yes' }), 'traditional must be a boolean')
require('intercal').setup({ serverPath = '/nowhere' })
t.equal(lsp.server, nil, 'a wrong serverPath finds nothing')

-- A server of another version, and one that falls over: one warning each.
local function fake_server(name, ...)
	local path = bin .. '/' .. name
	local command = vim.tbl_map(vim.fn.shellescape, { vim.v.progpath, '--clean', '-l', t.fixtures .. '/fake_server.lua', ... })
	vim.fn.writefile({ '#!/bin/sh', 'exec ' .. table.concat(command, ' ') }, path)
	vim.uv.fs_chmod(path, 493)
	return path
end
local function warnings_containing(text)
	return #vim.tbl_filter(function(n)
		return n.message:find(text, 1, true) ~= nil
	end, notifications)
end
local function open_and_wait(name, condition, timeout_ms)
	vim.cmd.edit(copy('sample.i', name))
	vim.wait(timeout_ms or 10000, condition, 20)
end

fresh()
require('intercal').setup({ serverPath = fake_server('ioi-old', '9.9.9') })
open_and_wait('old.i', function()
	return warnings_containing('is version 9.9.9, and this plugin is 0.0.0') > 0
end)
open_and_wait('old2.i', function()
	return #vim.lsp.get_clients({ bufnr = 0, name = 'intercal' }) > 0
end)
t.equal(warnings_containing('is version 9.9.9, and this plugin is 0.0.0'), 1, 'version mismatch warnings')
t.equal(#vim.lsp.get_clients({ bufnr = 0, name = 'intercal' }), 1, 'a mismatched server still runs')
t.equal(warnings_containing('fell over'), 0, 'crash warnings before anything crashed')

fresh()
require('intercal').setup({ serverPath = fake_server('ioi-crash', '0.0.0', 'crash') })
open_and_wait('crash.i', function()
	return warnings_containing('fell over (exit code 7') > 0
end)
open_and_wait('crash2.i', function()
	return warnings_containing('fell over') > 1
end, 500)
t.equal(warnings_containing('fell over (exit code 7'), 1, 'crash warnings')
t.equal(warnings_containing('is version'), 1, 'no version warning for a matching server')

-- Templates: .html buffers join the server once an INTERCAL program has started it.
fresh()
require('intercal').setup({ serverPath = fake_server('ioi-good', '0.0.0') })
local function html(name)
	local path = scratch .. '/' .. name
	vim.fn.writefile({ '<p>{{ ,1 }}</p>' }, path)
	vim.cmd.edit(path)
	return vim.api.nvim_get_current_buf()
end
local function attached(bufnr)
	return #vim.lsp.get_clients({ bufnr = bufnr, name = 'intercal' }) > 0
end
local early = html('early.html')
t.drain()
t.check(not attached(early), 'an .html file alone does not start the server')
vim.cmd.edit(copy('sample.i', 'site.ioi'))
local program = vim.api.nvim_get_current_buf()
vim.wait(5000, function()
	return attached(program) and attached(early)
end, 20)
t.check(attached(program), 'the server attaches to a .ioi program')
t.check(attached(early), 'and to the .html files already open')
local late = html('late.html')
vim.wait(5000, function()
	return attached(late)
end, 20)
t.check(attached(late), 'and to .html files opened afterwards')
t.equal(#vim.lsp.get_clients({ name = 'intercal' }), 1, 'one server for the program and its templates')

-- The comment mappings in INTERCAL buffers, and only there.
vim.cmd.edit(t.fixtures .. '/sample.i')
t.equal(vim.fn.maparg('gcc', 'n', false, true).buffer, 1, 'gcc is mapped in INTERCAL buffers')
t.equal(vim.fn.maparg('gc', 'x', false, true).buffer, 1, 'visual gc is mapped in INTERCAL buffers')
vim.cmd.edit(swig)
t.check(vim.fn.maparg('gcc', 'n', false, true).buffer ~= 1, 'gcc is left alone elsewhere')
t.equal(vim.fn.exists(':IntercalToggleComment'), 2, ':IntercalToggleComment exists')
t.equal(vim.fn.exists(':IntercalRun'), 2, ':IntercalRun exists')
t.equal(vim.fn.exists(':IntercalBuild'), 2, ':IntercalBuild exists')

-- gcc asks the server for the edits and applies them.
vim.cmd.edit(copy('sample.i', 'toggle.i'))
local toggled
lsp.client_for = function()
	return {
		offset_encoding = 'utf-16',
		request = function(_, method, params, handler)
			toggled = { method, params }
			handler(nil, { { range = { start = { line = 1, character = 1 }, ['end'] = { line = 1, character = 7 } }, newText = 'PLEASE NOTE' } })
		end
	}
end
vim.api.nvim_win_set_cursor(0, { 2, 0 })
vim.cmd('normal gcc')
t.equal(toggled, { 'intercal/toggleComment', {
	textDocument = { uri = vim.uri_from_bufnr(0) },
	range = { start = { line = 1, character = 0 }, ['end'] = { line = 1, character = 19 } }
} }, 'gcc sends the line to intercal/toggleComment')
t.equal(vim.api.nvim_buf_get_lines(0, 1, 2, true), { '\tPLEASE NOTE READ OUT .2' }, 'gcc applies the edits')
vim.cmd('2,3IntercalToggleComment')
t.equal(toggled[2].range, { start = { line = 1, character = 0 }, ['end'] = { line = 2, character = 11 } }, ':IntercalToggleComment sends its range')

-- ciwapa-lib: buffers, read through intercal/librarySource.
local requested
lsp.running_client = function()
	return {
		request_sync = function(_, method, params)
			requested = { method, params }
			return { result = { text = '(1000)\tPLEASE NOTE THE ADDITION\r\n\tPLEASE RESUME #1\n' } }
		end
	}
end
vim.cmd.edit('ciwapa-lib:/syslib.i')
t.equal(requested, { 'intercal/librarySource', { uri = 'ciwapa-lib:/syslib.i' } }, 'the library request')
t.equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { '(1000)\tPLEASE NOTE THE ADDITION', '\tPLEASE RESUME #1' }, 'library text')
t.equal({ vim.bo.readonly, vim.bo.modifiable, vim.bo.buftype, vim.bo.filetype }, { true, false, 'nofile', 'intercal' }, 'library buffer options')

vim.fn.delete(scratch, 'rf')
vim.fn.delete(bin, 'rf')
vim.fn.delete(empty_path, 'rf')
t.finish('unit')
