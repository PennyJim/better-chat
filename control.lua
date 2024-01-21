
---Turns the message into a chat message
---@param sender LuaPlayer
---@param text string
local function processMessage(sender, text)
	local fullMessage = ""

	-- Add player name
	fullMessage = fullMessage..sender.name..": "

	fullMessage = fullMessage..message
	return fullMessage
end

---Clear everyone's console
local function global_console_clear()
	for _, player in pairs(game.players) do
		player.clear_console();
	end
end

---Processes messsage, saves it to history, then sends latest x messages
---@param sender LuaPlayer	
---@param message string
local function send_message(sender, message)
	local msg = processMessage(sender, message)
	local error = nil

	-- Mark duplicate if it's been sent in last x seconds
	local duplicate_timer = 60*settings.global["bc-duplicate-timer"].value
	for i = #global.chatHistory, 1, -1 do
		local chat = global.chatHistory[i]
		if (chat.tick < game.tick - duplicate_timer) then break
		elseif chat.msg == msg then
			error = {msg={"bc-warning.duplicate-message"}, type="warn"}
			break
		end
	end

	-- Remove oldest chat if new message and at max capacity
	if not error then
		-- HACK: add config change listener to pruge chatHistory if it shrinks instead of this
		if #global.chatHistory >= settings.global["bc-global-chat-history"].value then
			table.remove(global.chatHistory, 1)
		end
		global.chatHistory[#global.chatHistory+1] = {msg=msg,color=sender.chat_color,tick=game.tick}
	end

	--Reprint chat to modify latest message
	global_console_clear();
	for _, chat in pairs(global.chatHistory) do
		game.print(chat.msg, {
			color = chat.color,
			sound = defines.print_sound.never,
			skip = defines.print_skip.never
		})
	end

	if error then
		local errorColor = settings.get_player_settings(sender)
			["bc-"..error.type.."-color"].value
		sender.print(error.msg, {
			color = errorColor
		})
	end
end

script.on_event(defines.events.on_console_chat, function (event)
	send_message(game.get_player(event.player_index), event.message)
end)

script.on_init(function ()
	global.chatHistory = {}
end)
