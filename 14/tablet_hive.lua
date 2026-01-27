-- cmd_tablet.lua
-- Tablet command UI (compact, cmd_test-style)

local CMD_RECV_CHANNEL = 90
local CMD_SEND_CHANNEL = 91

local modem = peripheral.find("modem") or error("No modem found")
modem.open(CMD_SEND_CHANNEL)

local W, H = term.getSize()

-- -------- state --------
local TARGET_ID = 1
local logLines = {}
local LOG_MAX = math.max(4, H - 9)
local input = ""

local function log(s)
	s = tostring(s)
	table.insert(logLines, s)
	while #logLines > LOG_MAX do
		table.remove(logLines, 1)
	end
end

local function sendCmd(cmd)
	local out = ("id:%d %s"):format(TARGET_ID, cmd)
	modem.transmit(CMD_RECV_CHANNEL, CMD_SEND_CHANNEL, out)
	log("TX " .. cmd)
end

-- -------- UI --------
local function drawHeader()
	term.setCursorPos(1, 1)
	term.clearLine()
	term.write(("tablet | id:%d"):format(TARGET_ID))
end

local function drawMenu()
	term.setCursorPos(1, 3)
	print("T)id  1)status  2)startY")
	print("3)pause 4)resume 5)home")
	print("6)goto  7)stop  8)reset")
	print("9)clear log  0)quit")
end

local function drawLog()
	print("--log--")
	for _, l in ipairs(logLines) do
		print(l)
	end
end

local function render()
	term.clear()
	drawHeader()
	drawMenu()
	drawLog()
	term.setCursorPos(1, H)
	term.clearLine()
	term.write("> " .. input)
end

-- -------- input state --------
local mode = "menu"
local tmpX, tmpY = nil, nil

render()
log("ready")

while true do
	local e = { os.pullEvent() }

	if e[1] == "modem_message" and e[3] == CMD_SEND_CHANNEL then
		log("RX " .. tostring(e[5]))
		render()
	elseif e[1] == "char" then
		input = input .. e[2]
		render()
	elseif e[1] == "key" then
		if e[2] == keys.backspace then
			input = input:sub(1, -2)
			render()
		elseif e[2] == keys.enter then
			local entered = input
			input = ""
			render()

			if mode == "set_id" then
				local n = tonumber(entered)
				if n then
					TARGET_ID = n
					log("id set " .. n)
				end
				mode = "menu"
			elseif mode == "startlevel" then
				local y = tonumber(entered)
				if y then
					sendCmd("startlevel " .. y)
				end
				mode = "menu"
			elseif mode == "goto_x" then
				tmpX = tonumber(entered)
				mode = "goto_y"
				log("y:")
			elseif mode == "goto_y" then
				tmpY = tonumber(entered)
				mode = "goto_z"
				log("z:")
			elseif mode == "goto_z" then
				local z = tonumber(entered)
				if tmpX and tmpY and z then
					sendCmd(("goto %d %d %d"):format(tmpX, tmpY, z))
				end
				tmpX, tmpY = nil, nil
				mode = "menu"
			else
				if entered == "T" or entered == "t" then
					mode = "set_id"
					log("target id:")
				elseif entered == "1" then
					sendCmd("status")
				elseif entered == "2" then
					mode = "startlevel"
					log("startlevel y:")
				elseif entered == "3" then
					sendCmd("pause")
				elseif entered == "4" then
					sendCmd("resume")
				elseif entered == "5" then
					sendCmd("home")
				elseif entered == "6" then
					mode = "goto_x"
					log("x:")
				elseif entered == "7" then
					sendCmd("stop")
				elseif entered == "8" then
					sendCmd("reset")
				elseif entered == "9" then
					logLines = {}
					log("log cleared")
				elseif entered == "0" then
					term.clear()
					return
				end
			end

			render()
		end
	end
end
