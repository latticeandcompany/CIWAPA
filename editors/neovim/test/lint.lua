-- Lint without dependencies: every file compiles, uses no globals beyond Lua's and `vim`, and every
-- module loads. Run: nvim --clean -l test/lint.lua
local t = dofile(vim.fs.dirname(vim.fn.fnamemodify(arg[0], ':p')) .. '/harness.lua')

local allowed = {}
for name in ([[
	_G arg assert bit collectgarbage coroutine debug dofile error getfenv getmetatable io ipairs jit
	load loadfile loadstring math next os package pairs pcall print rawequal rawget rawlen rawset
	require select setfenv setmetatable string table tonumber tostring type unpack vim xpcall
]]):gmatch('%S+') do
	allowed[name] = true
end

local bytecode = require('jit.bc')

local function globals_of(chunk)
	local listing = {}
	bytecode.dump(chunk, { write = function(_, text) table.insert(listing, text) end, flush = function() end }, true)
	local found = {}
	for line in table.concat(listing):gmatch('[^\n]+') do
		local op, name = line:match('(G[GS]ET)%s.-"([^"]+)"')
		if op then
			table.insert(found, { op = op, name = name })
		end
	end
	return found
end

local files = vim.fs.find(function(name)
	return name:match('%.lua$') ~= nil
end, { path = t.root, type = 'file', limit = math.huge })
table.sort(files)

for _, file in ipairs(files) do
	local relative = file:sub(#t.root + 2)
	local chunk, err = loadfile(file)
	if not chunk then
		t.check(false, err)
	else
		for _, use in ipairs(globals_of(chunk)) do
			t.check(allowed[use.name], ('%s: %s of the global %q'):format(relative, use.op == 'GSET' and 'assignment' or 'use', use.name))
		end
	end
end

t.load_plugin()
for _, file in ipairs(files) do
	local module = file:match('/lua/(intercal/.-)%.lua$')
	if module then
		local ok, err = pcall(require, (module:gsub('/', '.'):gsub('%.init$', '')))
		t.check(ok, ('require %s: %s'):format(module, tostring(err)))
	end
end

t.check(#files >= 10, ('found only %d Lua files under %s'):format(#files, t.root))
t.finish('lint')
