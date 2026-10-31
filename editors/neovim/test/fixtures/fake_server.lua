-- A stand-in language server for the unit checks: `nvim --clean -l fake_server.lua <version> [crash]`
-- answers initialize with that version, then either serves until exit or falls over.
local version, crash = arg[1], arg[2] == 'crash'

local function read_message()
	local length
	while true do
		local header = io.stdin:read('*l')
		if header == nil then
			os.exit(0)
		end
		header = header:gsub('\r$', '')
		if header == '' then
			break
		end
		length = tonumber(header:match('^Content%-Length: (%d+)')) or length
	end
	return vim.json.decode(io.stdin:read(length))
end

local function send(message)
	message.jsonrpc = '2.0'
	local body = vim.json.encode(message)
	io.stdout:write(('Content-Length: %d\r\n\r\n%s'):format(#body, body))
	io.stdout:flush()
end

while true do
	local message = read_message()
	if message.method == 'initialize' then
		send({ id = message.id, result = { capabilities = { textDocumentSync = 1 }, serverInfo = { name = 'fake', version = version } } })
	elseif message.method == 'initialized' and crash then
		os.exit(7)
	elseif message.method == 'shutdown' then
		send({ id = message.id, result = vim.NIL })
	elseif message.method == 'exit' then
		os.exit(0)
	elseif message.id then
		send({ id = message.id, result = vim.NIL })
	end
end
